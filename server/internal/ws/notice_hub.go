package ws

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

const websocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

var Notices = newNoticeHub()

type noticeHub struct {
	mu      sync.RWMutex
	clients map[uint64]map[chan []byte]struct{}
}

func newNoticeHub() *noticeHub {
	return &noticeHub{clients: make(map[uint64]map[chan []byte]struct{})}
}

func (h *noticeHub) Push(userID uint64, notice model.Notice) {
	payload, err := json.Marshal(gin.H{"event": "notice", "data": notice})
	if err != nil {
		return
	}

	h.mu.RLock()
	clients := h.clients[userID]
	for ch := range clients {
		select {
		case ch <- payload:
		default:
		}
	}
	h.mu.RUnlock()
}

func (h *noticeHub) ServeNoticeSocket(c *gin.Context) {
	userID, err := parseUserID(c.Query("token"))
	if err != nil {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "token 无效或已过期"})
		return
	}

	conn, reader, err := upgrade(c.Writer, c.Request)
	if err != nil {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"code": 400, "message": "WebSocket 握手失败"})
		return
	}
	defer conn.Close()

	ch := make(chan []byte, 16)
	h.add(userID, ch)
	defer h.remove(userID, ch)

	closed := make(chan struct{})
	go func() {
		defer close(closed)
		for {
			if _, err := readFrame(reader); err != nil {
				return
			}
		}
	}()

	for {
		select {
		case payload := <-ch:
			if err := writeTextFrame(conn, payload); err != nil {
				return
			}
		case <-closed:
			return
		}
	}
}

func (h *noticeHub) add(userID uint64, ch chan []byte) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.clients[userID] == nil {
		h.clients[userID] = make(map[chan []byte]struct{})
	}
	h.clients[userID][ch] = struct{}{}
}

func (h *noticeHub) remove(userID uint64, ch chan []byte) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.clients[userID], ch)
	close(ch)
	if len(h.clients[userID]) == 0 {
		delete(h.clients, userID)
	}
}

func parseUserID(rawToken string) (uint64, error) {
	if rawToken == "" {
		return 0, errors.New("missing token")
	}
	claims := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(rawToken, claims, func(t *jwt.Token) (interface{}, error) {
		return []byte(config.App.JWTSecret), nil
	})
	if err != nil || !token.Valid {
		return 0, errors.New("invalid token")
	}
	userID, ok := claims["user_id"].(float64)
	if !ok || userID <= 0 {
		return 0, errors.New("invalid user")
	}
	return uint64(userID), nil
}

func upgrade(w http.ResponseWriter, r *http.Request) (net.Conn, *bufio.Reader, error) {
	key := r.Header.Get("Sec-WebSocket-Key")
	if key == "" || !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
		return nil, nil, errors.New("invalid websocket request")
	}
	hj, ok := w.(http.Hijacker)
	if !ok {
		return nil, nil, errors.New("hijacker unsupported")
	}
	conn, rw, err := hj.Hijack()
	if err != nil {
		return nil, nil, err
	}
	accept := websocketAccept(key)
	_, err = rw.WriteString("HTTP/1.1 101 Switching Protocols\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Sec-WebSocket-Accept: " + accept + "\r\n\r\n")
	if err != nil {
		conn.Close()
		return nil, nil, err
	}
	if err := rw.Flush(); err != nil {
		conn.Close()
		return nil, nil, err
	}
	return conn, rw.Reader, nil
}

func websocketAccept(key string) string {
	sum := sha1.Sum([]byte(key + websocketGUID))
	return base64.StdEncoding.EncodeToString(sum[:])
}

func writeTextFrame(w io.Writer, payload []byte) error {
	header := []byte{0x81}
	switch l := len(payload); {
	case l < 126:
		header = append(header, byte(l))
	case l <= 65_535:
		header = append(header, 126, byte(l>>8), byte(l))
	default:
		header = append(header, 127, byte(l>>56), byte(l>>48), byte(l>>40), byte(l>>32), byte(l>>24), byte(l>>16), byte(l>>8), byte(l))
	}
	if _, err := w.Write(header); err != nil {
		return err
	}
	_, err := w.Write(payload)
	return err
}

func readFrame(r *bufio.Reader) ([]byte, error) {
	header := make([]byte, 2)
	if _, err := io.ReadFull(r, header); err != nil {
		return nil, err
	}
	length := int(header[1] & 0x7F)
	if length == 126 {
		ext := make([]byte, 2)
		if _, err := io.ReadFull(r, ext); err != nil {
			return nil, err
		}
		length = int(ext[0])<<8 | int(ext[1])
	} else if length == 127 {
		ext := make([]byte, 8)
		if _, err := io.ReadFull(r, ext); err != nil {
			return nil, err
		}
		length = int(ext[4])<<24 | int(ext[5])<<16 | int(ext[6])<<8 | int(ext[7])
	}
	mask := make([]byte, 4)
	if header[1]&0x80 != 0 {
		if _, err := io.ReadFull(r, mask); err != nil {
			return nil, err
		}
	}
	payload := make([]byte, length)
	if _, err := io.ReadFull(r, payload); err != nil {
		return nil, err
	}
	for i := range payload {
		payload[i] ^= mask[i%4]
	}
	return payload, nil
}

package geoip

import (
	"encoding/json"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

type Detail struct {
	Country string
	Region  string
	City    string
	ISP     string
}

type cacheItem struct {
	detail Detail
	ok     bool
	expire time.Time
}

type ipWhoisResponse struct {
	Success    bool   `json:"success"`
	Country    string `json:"country"`
	Region     string `json:"region"`
	City       string `json:"city"`
	Message    string `json:"message"`
	Connection struct {
		ISP string `json:"isp"`
		Org string `json:"org"`
	} `json:"connection"`
}

var (
	cacheMu sync.RWMutex
	cache   = map[string]cacheItem{}
	client  = &http.Client{Timeout: 2 * time.Second}
)

func Load(string) error {
	return nil
}

func LoadASN(string) error {
	return nil
}

func Lookup(ip string) (Detail, bool) {
	if item, ok := readCache(ip); ok {
		return item.detail, item.ok
	}

	detail, ok := lookupOnline(ip)
	expire := time.Now().Add(24 * time.Hour)
	if !ok {
		expire = time.Now().Add(10 * time.Minute)
	}
	writeCache(ip, cacheItem{detail: detail, ok: ok, expire: expire})
	return detail, ok
}

func Format(detail Detail) string {
	parts := make([]string, 0, 4)
	for _, part := range []string{detail.Country, detail.Region, detail.City, detail.ISP} {
		if part != "" {
			parts = append(parts, part)
		}
	}
	if len(parts) == 0 {
		return ""
	}
	return strings.Join(parts, " / ")
}

func Describe(ip string) map[string]interface{} {
	parsed := net.ParseIP(ip)
	detail := map[string]interface{}{"ip": ip, "type": "unknown", "is_private": false, "location": "未知"}
	if parsed == nil {
		return detail
	}
	if parsed.IsLoopback() {
		detail["type"] = "loopback"
		detail["location"] = "本机"
		return detail
	}
	if parsed.IsPrivate() {
		detail["type"] = "private"
		detail["is_private"] = true
		detail["location"] = privateIPLocation(ip)
		return detail
	}
	if parsed.To4() != nil {
		detail["type"] = "ipv4"
	} else {
		detail["type"] = "ipv6"
	}

	if geo, ok := Lookup(ip); ok {
		detail["location"] = Format(geo)
		detail["country"] = geo.Country
		detail["region"] = geo.Region
		detail["city"] = geo.City
		detail["isp"] = geo.ISP
		return detail
	}

	detail["location"] = "GeoIP 查询失败"
	return detail
}

func IsLoaded() bool {
	return true
}

func IsNotExist(error) bool {
	return false
}

func lookupOnline(ip string) (Detail, bool) {
	apiURL := "https://ipwho.is/" + url.PathEscape(ip) + "?lang=zh-CN"
	resp, err := client.Get(apiURL)
	if err != nil {
		return Detail{}, false
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return Detail{}, false
	}

	var data ipWhoisResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return Detail{}, false
	}
	if !data.Success {
		return Detail{}, false
	}

	isp := data.Connection.ISP
	if isp == "" {
		isp = data.Connection.Org
	}

	detail := Detail{
		Country: strings.TrimSpace(data.Country),
		Region:  strings.TrimSpace(data.Region),
		City:    strings.TrimSpace(data.City),
		ISP:     strings.TrimSpace(isp),
	}
	return detail, detail.Country != "" || detail.Region != "" || detail.City != "" || detail.ISP != ""
}

func readCache(ip string) (cacheItem, bool) {
	cacheMu.RLock()
	item, ok := cache[ip]
	cacheMu.RUnlock()
	if !ok || time.Now().After(item.expire) {
		return cacheItem{}, false
	}
	return item, true
}

func writeCache(ip string, item cacheItem) {
	cacheMu.Lock()
	cache[ip] = item
	cacheMu.Unlock()
}

func privateIPLocation(ip string) string {
	switch {
	case strings.HasPrefix(ip, "192.168."):
		return "局域网 192.168.x.x"
	case strings.HasPrefix(ip, "10."):
		return "局域网 10.x.x.x"
	case strings.HasPrefix(ip, "172."):
		return "局域网 172.16-31.x.x"
	default:
		return "内网地址"
	}
}

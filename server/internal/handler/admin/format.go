package admin

import "time"

func formatDateTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.Format("2006-01-02 15:04:05")
}

func loginStatusText(status int8) string {
	if status == 1 {
		return "成功"
	}
	return "失败"
}

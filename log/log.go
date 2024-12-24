package log

import (
	"bytes"
	"fmt"
	"log"
	"os"
	"sync"
	"time"
)

const (
	LevelDebug = "DEBUG"
	LevelInfo  = "INFO"
	LevelWarn  = "WARN"
	LevelError = "ERROR"
	LevelFatal = "FATAL"
	ColorReset = "\033[0m"
	ColorDebug = "\033[34m"
	ColorInfo  = "\033[32m"
	ColorWarn  = "\033[33m"
	ColorError = "\033[31m"
	ColorFatal = "\033[35m"
)

var (
	colors = map[string]string{
		LevelDebug: ColorDebug,
		LevelInfo:  ColorInfo,
		LevelWarn:  ColorWarn,
		LevelError: ColorError,
		LevelFatal: ColorFatal,
	}
	mu sync.Mutex
)

type Adapter struct{}

func (a *Adapter) Write(p []byte) (n int, err error) {
	Warn("%v", string(bytes.TrimSpace(p)))
	return len(p), nil
}

func NewLogger() *log.Logger {
	return log.New(&Adapter{}, "", 0)
}

func logger(level, format string, v ...interface{}) {
	mu.Lock()
	defer mu.Unlock()
	timestamp := time.Now().Format("2006-01-02 15:04:05.000")
	color := colors[level]
	message := fmt.Sprintf(format, v...)
	fmt.Printf("%v  %v%v%v  %v\n", timestamp, color, level, ColorReset, message)
	if level == LevelFatal {
		os.Exit(1)
	}
}

func Debug(format string, v ...interface{}) {
	logger(LevelInfo, format, v...)
}

func Info(format string, v ...interface{}) {
	logger(LevelInfo, format, v...)
}

func Warn(format string, v ...interface{}) {
	logger(LevelWarn, format, v...)
}

func Error(format string, v ...interface{}) {
	logger(LevelError, format, v...)
}

func Fatal(format string, v ...interface{}) {
	logger(LevelFatal, format, v...)
}

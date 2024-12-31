package log

import (
	"bytes"
	"fmt"
	"log"
	"sync"
	"time"
)

type LogLevel int

const (
	Debug LogLevel = iota
	Info
	Warn
	Error
	Fatal
)

var levelStrings = map[LogLevel]string{
	Debug: "DEBUG",
	Info:  "INFO",
	Warn:  "WARN",
	Error: "ERROR",
	Fatal: "FATAL",
}

const (
	ansiBlue   = "\033[34m"
	ansiGreen  = "\033[32m"
	ansiYellow = "\033[33m"
	ansiRed    = "\033[31m"
	ansiPurple = "\033[35m"
	resetColor = "\033[0m"
)

var levelColors = map[LogLevel]string{
	Debug: ansiBlue,
	Info:  ansiGreen,
	Warn:  ansiYellow,
	Error: ansiRed,
	Fatal: ansiPurple,
}

type Logger struct {
	mu          sync.Mutex
	minLogLevel LogLevel
	enableColor bool
}

type logAdapter struct {
	logger *Logger
}

func (l *Logger) StdLogger() *log.Logger {
	return log.New(&logAdapter{logger: l}, "", 0)
}

func (a *logAdapter) Write(p []byte) (n int, err error) {
	a.logger.Warn("Internal: %s", string(bytes.TrimSpace(p)))
	return len(p), nil
}

func NewLogger(logLevel LogLevel, enableColor bool) *Logger {
	if logLevel < Debug || logLevel > Fatal {
		logLevel = Info
	}
	return &Logger{
		mu:          sync.Mutex{},
		minLogLevel: logLevel,
		enableColor: enableColor,
	}
}

func (l *Logger) SetLogLevel(logLevel LogLevel) {
	if l.minLogLevel != logLevel {
		l.mu.Lock()
		defer l.mu.Unlock()
		l.minLogLevel = logLevel
	}
}

func (l *Logger) GetLogLevel() LogLevel {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.minLogLevel
}

func (l *Logger) EnableColor(enable bool) {
	if l.enableColor != enable {
		l.mu.Lock()
		defer l.mu.Unlock()
		l.enableColor = enable
	}
}

func (l *Logger) log(logLevel LogLevel, format string, v ...interface{}) {
	if logLevel < Debug || logLevel > Fatal {
		logLevel = Info
	}
	if logLevel < l.minLogLevel {
		return
	}
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	levelStr := levelStrings[logLevel]
	message := fmt.Sprintf(format, v...)
	l.mu.Lock()
	defer l.mu.Unlock()
	l.writeLog(logLevel, timestamp, levelStr, message)
}

func (l *Logger) writeLog(level LogLevel, timestamp, levelStr, message string) {
	if l.enableColor {
		colorCode := levelColors[level]
		fmt.Printf("%s  %s%s%s  %s\n", timestamp, colorCode, levelStr, resetColor, message)
	} else {
		fmt.Printf("%s  %s  %s\n", timestamp, levelStr, message)
	}
}

func (l *Logger) Debug(format string, v ...interface{}) {
	l.log(Debug, format, v...)
}

func (l *Logger) Info(format string, v ...interface{}) {
	l.log(Info, format, v...)
}

func (l *Logger) Warn(format string, v ...interface{}) {
	l.log(Warn, format, v...)
}

func (l *Logger) Error(format string, v ...interface{}) {
	l.log(Error, format, v...)
}

func (l *Logger) Fatal(format string, v ...interface{}) {
	l.log(Fatal, format, v...)
}

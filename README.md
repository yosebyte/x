# yosebyte/x

A comprehensive utility library for Go applications that provides robust connection management, TLS configuration generation, and structured logging. This library is designed to simplify common networking and operational tasks in Go applications with a focus on reliability and performance.

[![Go Reference](https://pkg.go.dev/badge/github.com/yosebyte/x.svg)](https://pkg.go.dev/github.com/yosebyte/x)
[![Go Report Card](https://goreportcard.com/badge/github.com/yosebyte/x)](https://goreportcard.com/report/github.com/yosebyte/x)

## Table of Contents

- [Installation](#installation)
- [Packages](#packages)
  - [conn - Connection Pooling and I/O Utilities](#conn---connection-pooling-and-io-utilities)
  - [tls - TLS Configuration Generator](#tls---tls-configuration-generator)
  - [log - Structured Logging](#log---structured-logging)
- [Performance Considerations](#performance-considerations)
- [Thread Safety](#thread-safety)
- [Contributing](#contributing)
- [License](#license)

## Installation

```bash
go get github.com/yosebyte/x
```

For a specific version:

```bash
go get github.com/yosebyte/x
```

To update to the latest version:

```bash
go get -u github.com/yosebyte/x
```

## Packages

### conn - Connection Pooling and I/O Utilities

The `conn` package provides sophisticated connection pooling mechanisms and data exchange utilities for managing network connections efficiently.

```go
import "github.com/yosebyte/x/conn"
```

#### Connection Pools

Three specialized types of connection pools are available, each designed for different use cases:

##### BrokerPool

Maintains a dynamic pool of connections for broker applications, with automatic scaling and connection health checking.

```go
// Create a broker pool with min/max capacity and connection interval management
pool := conn.NewBrokerPool(
    5,                  // minimum capacity
    20,                 // maximum capacity
    time.Second,        // minimum interval
    time.Minute,        // maximum interval
    func() (net.Conn, error) {
        return net.Dial("tcp", "example.com:80")
    },
)

// Start the connection manager in a goroutine
go pool.BrokerManager()

// Get a connection from the pool
id, netConn := pool.BrokerGet()
if netConn == nil {
    // Handle connection error
    fmt.Println("Connection error:", id)
    return
}

// Use the connection
// ...

// Close the pool when done with all operations
defer pool.Close()

// Check the current active connections and capacity
fmt.Printf("Active connections: %d, Capacity: %d\n", pool.Active(), pool.Capacity())
```

##### ClientPool

Manages outbound client connections with automatic scaling based on usage patterns.

```go
// Create a client pool
clientPool := conn.NewClientPool(
    3,                  // minimum capacity
    10,                 // maximum capacity
    func() (net.Conn, error) {
        return net.Dial("tcp", "api.example.com:443")
    },
)

// Start the client manager
go clientPool.ClientManager()

// Retrieve a specific connection by ID
conn := clientPool.ClientGet("connection-id")
```

##### ServerPool

Handles incoming server connections with built-in acceptance limiting.

```go
// Create a TCP listener
listener, err := net.Listen("tcp", ":8080")
if err != nil {
    log.Fatal(err)
}

// Create a server pool
serverPool := conn.NewServerPool(100, listener) // max 100 connections

// Start the server manager
go serverPool.ServerManager()

// Get a new connection with its ID
id, conn := serverPool.ServerGet()
```

#### Connection Pool Management

All pool types offer methods to monitor and control the connection lifecycle:

```go
// Get the current number of active connections
activeCount := pool.Active()

// Get the current capacity setting
capacity := pool.Capacity()

// Get the current interval between connection attempts (BrokerPool only)
interval := pool.Interval()

// Close all connections in the pool
pool.Close()
```

#### Data Exchange

The package includes a highly efficient bidirectional data exchange function that handles proper connection closure and error propagation:

```go
// Exchange data between two connections (e.g., proxy implementation)
bytesClient2Server, bytesServer2Client, err := conn.DataExchange(clientConn, serverConn)

if err != nil && err != io.EOF {
    fmt.Printf("Data exchange error: %v\n", err)
}

fmt.Printf("Transferred %d bytes from client to server\n", bytesClient2Server)
fmt.Printf("Transferred %d bytes from server to client\n", bytesServer2Client)
```

### tls - TLS Configuration Generator

The `tls` package simplifies the creation of TLS configurations with self-signed certificates for development, testing, or internal services.

```go
import "github.com/yosebyte/x/tls"
```

#### Generate Self-Signed TLS Configuration

Create a TLS configuration with a dynamically generated self-signed certificate:

```go
// Generate a TLS config with organization name "my-application"
tlsConfig, err := tls.GenerateTLSConfig("my-application")
if err != nil {
    log.Fatalf("Failed to generate TLS config: %v", err)
}

// Use the config with a TLS listener
listener, err := tls.Listen("tcp", ":443", tlsConfig)
if err != nil {
    log.Fatalf("Failed to create TLS listener: %v", err)
}

// Accept TLS connections
for {
    conn, err := listener.Accept()
    if err != nil {
        log.Printf("Accept error: %v", err)
        continue
    }
    
    go handleConnection(conn)
}
```

#### Key Certificate Details

The generated certificate:
- Uses a 2048-bit RSA key
- Is valid for 365 days from creation
- Includes the provided organization name
- Has appropriate key usages for server authentication

This is ideal for:
- Development environments
- Internal services
- Testing TLS implementations
- Situations where obtaining a public CA certificate is not practical

### log - Structured Logging

The `log` package provides a simple yet powerful logging system with level-based filtering, color-coded output, and formatting support.

```go
import "github.com/yosebyte/x/log"
```

#### Creating a Logger

```go
// Create a new logger with minimum log level and color enabled
logger := log.NewLogger(log.Info, true)
```

#### Log Levels

The package supports five standard log levels with corresponding methods:

```go
// Available log levels in increasing order of severity
logger.Debug("Database query completed in %d ms", queryTime) // Detailed debugging information
logger.Info("User %s logged in successfully", username)      // Normal operational messages
logger.Warn("API rate limit at 80%% capacity")               // Warning conditions
logger.Error("Failed to connect to database: %v", err)       // Error conditions
logger.Fatal("System shutdown due to critical failure")      // Critical errors
```

#### Dynamic Configuration

Log settings can be adjusted at runtime:

```go
// Change minimum log level dynamically
logger.SetLogLevel(log.Debug)  // Show all logs including debug
logger.SetLogLevel(log.Error)  // Show only error and fatal logs

// Get current log level
currentLevel := logger.GetLogLevel()

// Toggle colored output
logger.EnableColor(false)  // Disable colors (useful for log files)
logger.EnableColor(true)   // Enable colors (better for console)
```

#### Standard Library Integration

The logger can be adapted to work with packages expecting the standard library logger:

```go
// Get a standard library logger adapter
stdLogger := logger.StdLogger()

// Use with standard library interfaces
http.DefaultClient.Transport = &http.Transport{
    DialContext: (&net.Dialer{
        Timeout:   30 * time.Second,
        KeepAlive: 30 * time.Second,
    }).DialContext,
    MaxIdleConns:          100,
    IdleConnTimeout:       90 * time.Second,
    TLSHandshakeTimeout:   10 * time.Second,
    ExpectContinueTimeout: 1 * time.Second,
}
http.DefaultClient.Transport.(*http.Transport).DisableCompression = true

// Messages logged through the standard logger will appear in your custom logger
// with the "Internal:" prefix at Debug level
```

#### Color-Coded Output

When color is enabled, log levels are displayed with distinctive colors:
- DEBUG: Blue
- INFO: Green
- WARN: Yellow
- ERROR: Red
- FATAL: Purple

## Performance Considerations

- Connection pools automatically adjust capacity based on usage patterns
- TLS certificate generation is CPU-intensive and should be done during startup
- Logging has minimal overhead, especially when higher log levels are filtered out

## Thread Safety

All components in this library are designed to be thread-safe and can be safely used from multiple goroutines.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[MIT License](LICENSE)

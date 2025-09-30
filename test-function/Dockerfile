FROM golang:1.25.1

WORKDIR /app

COPY go.mod ./

RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /test-function

CMD ["/test-function"]

FROM golang:1.25.1 as base

WORKDIR /app

COPY go.mod ./

RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /test-function


from scratch as app
COPY --from=base /test-function /test-function

ENTRYPOINT ["/test-function"]

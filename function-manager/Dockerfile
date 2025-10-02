FROM golang:1.25.1 as base

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /function-manager


from scratch as app
COPY --from=base /function-manager /function-manager

ENTRYPOINT ["/function-manager"]

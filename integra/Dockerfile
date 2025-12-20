# Integra Chain Dockerfile
# Multi-stage build for minimal production image

# Build stage
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git make gcc musl-dev linux-headers

WORKDIR /app

# Copy the entire cosmos/evm repo (needed for local replace directive)
COPY . /app/

# Build the intgd binary
WORKDIR /app/integra
RUN go mod download
RUN CGO_ENABLED=1 go build -o /intgd ./cmd/intgd

# Production stage
FROM alpine:3.19

RUN apk add --no-cache ca-certificates jq bash

# Copy binary
COPY --from=builder /intgd /usr/local/bin/intgd

# Create user
RUN adduser -D integra
USER integra

# Set up directories
RUN mkdir -p /home/integra/.integra

WORKDIR /home/integra

EXPOSE 26656 26657 1317 8545 8546 9090

ENTRYPOINT ["intgd"]
CMD ["start"]


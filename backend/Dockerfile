FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/cruce-api ./cmd/api

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/cruce-api /cruce-api
ENV PORT=8080
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/cruce-api"]

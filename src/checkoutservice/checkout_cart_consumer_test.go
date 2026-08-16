//go:build consumer
// +build consumer

package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	pactlog "github.com/pact-foundation/pact-go/v2/log"
	message "github.com/pact-foundation/pact-go/v2/message/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Consumer-driven contract: checkoutservice → cartservice
// RPC GetCart — primeira chamada do fluxo PlaceOrder (main.go:324-330).
// Provider state: um carrinho preexistente para o usuário.
func TestCheckoutGetCart(t *testing.T) {
	p, err := message.NewSynchronousPact(message.Config{
		Consumer: "checkoutservice",
		Provider: "cartservice",
		PactDir:  filepath.ToSlash(fmt.Sprintf("%s/../../pacts", mustGetwd(t))),
	})
	require.NoError(t, err)
	pactlog.SetLogLevel("INFO")
	protoPath := filepath.ToSlash(fmt.Sprintf("%s/../../protos/demo.proto", mustGetwd(t)))

	grpcInteraction := `{
		"pact:proto": "` + protoPath + `",
		"pact:proto-service": "CartService/GetCart",
		"pact:content-type": "application/grpc",
		"request": {
			"user_id": "matching(type, 'abc123')"
		},
		"response": {
			"user_id": "matching(type, 'abc123')",
			"items": {
				"product_id": "matching(type, 'OLJCESPC7Z')",
				"quantity": "matching(type, 2)"
			}
		}
	}`

	err = p.AddSynchronousMessage("A request to get a user's cart").
		Given("user 'abc123' has an existing cart").
		UsingPlugin(message.PluginConfig{
			Plugin:  "protobuf",
			Version: "0.8.0",
		}).
		WithContents(grpcInteraction, "application/protobuf").
		StartTransport("grpc", "127.0.0.1", nil).
		ExecuteTest(t, func(transport message.TransportConfig, m message.SynchronousMessage) error {
			conn, err := grpc.NewClient(
				fmt.Sprintf("127.0.0.1:%d", transport.Port),
				grpc.WithTransportCredentials(insecure.NewCredentials()),
			)
			if err != nil {
				t.Fatal("unable to connect to mock gRPC server", err)
			}
			defer conn.Close()

			// Consumidor real: checkoutService com a conexão injetada
			cs := &checkoutService{cartSvcConn: conn}

			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			items, err := cs.getUserCart(ctx, "abc123")

			if err != nil {
				return fmt.Errorf("getUserCart falhou: %+v", err)
			}

			assert.Len(t, items, 1)
			assert.Equal(t, "OLJCESPC7Z", items[0].GetProductId())
			assert.Equal(t, int32(2), items[0].GetQuantity())

			return nil
		})

	assert.NoError(t, err)
}

func mustGetwd(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	return strings.ReplaceAll(dir, "\\", "/")
}

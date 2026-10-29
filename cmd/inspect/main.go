// inspect is a read-only BSC JSON-RPC investigation tool.
// It never signs transactions, holds keys, or changes on-chain state.
package main

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"os"
	"strings"
	"time"
)

const (
	caseTx             = "0xb180b03b30a368c112855a79bd90cec5597204c20d6b6bdf14c5cf8ee1af8f77"
	officialUSDT       = "0x55d398326f99059fF775485246999027B3197955"
	eip1167Prefix      = "363d3d373d3d3d363d73"
	eip1167Suffix      = "5af43d82803e903d91602b57fd5bf3"
	transferEventTopic = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
)

// Event logs are emitted by the execution context address (clone for DELEGATECALL),
// not by the contract containing the implementation bytecode.
type eventLog struct {
	Address string   `json:"address"`
	Topics  []string `json:"topics"`
	Data    string   `json:"data"`
}

func parseTransferEvent(log eventLog) (from, to string, amount *big.Int, ok bool) {
	if len(log.Topics) != 3 || !strings.EqualFold(log.Topics[0], transferEventTopic) {
		return "", "", nil, false
	}
	for _, topic := range log.Topics[1:] {
		if len(topic) != 66 || !strings.HasPrefix(topic, "0x") {
			return "", "", nil, false
		}
		if _, err := hex.DecodeString(topic[2:]); err != nil {
			return "", "", nil, false
		}
	}
	if len(log.Data) != 66 {
		return "", "", nil, false
	}
	amount, err := uint256Hex(log.Data)
	if err != nil {
		return "", "", nil, false
	}
	return "0x" + log.Topics[1][26:], "0x" + log.Topics[2][26:], amount, true
}

type rpcClient struct {
	endpoint string
	http     *http.Client
}
type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *rpcError) Error() string { return fmt.Sprintf("RPC %d: %s", e.Code, e.Message) }

func (c rpcClient) call(ctx context.Context, method string, params []any, result any) error {
	data, err := json.Marshal(map[string]any{
		"jsonrpc": "2.0", "id": 1, "method": method, "params": params,
	})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d from RPC", res.StatusCode)
	}
	var envelope struct {
		Result json.RawMessage `json:"result"`
		Error  *rpcError       `json:"error"`
	}
	if err := json.NewDecoder(io.LimitReader(res.Body, 2<<20)).Decode(&envelope); err != nil {
		return err
	}
	if envelope.Error != nil {
		return envelope.Error
	}
	if len(envelope.Result) == 0 || string(envelope.Result) == "null" {
		return errors.New("RPC returned no result")
	}
	return json.Unmarshal(envelope.Result, result)
}

func minimalProxyTarget(runtime string) (string, bool) {
	runtime = strings.TrimPrefix(strings.ToLower(runtime), "0x")
	if len(runtime) != 90 || !strings.HasPrefix(runtime, eip1167Prefix) || !strings.HasSuffix(runtime, eip1167Suffix) {
		return "", false
	}
	return "0x" + runtime[len(eip1167Prefix):len(eip1167Prefix)+40], true
}

func balanceOfCallData(wallet string) (string, error) {
	wallet = strings.TrimPrefix(strings.ToLower(wallet), "0x")
	if len(wallet) != 40 {
		return "", errors.New("address must be exactly 20 bytes")
	}
	if _, err := hex.DecodeString(wallet); err != nil {
		return "", fmt.Errorf("invalid address: %w", err)
	}
	return "0x70a08231" + strings.Repeat("0", 24) + wallet, nil
}

func uint256Hex(value string) (*big.Int, error) {
	n, ok := new(big.Int).SetString(strings.TrimPrefix(value, "0x"), 16)
	if !ok {
		return nil, fmt.Errorf("bad hex quantity %q", value)
	}
	return n, nil
}

func tokenUnits(value *big.Int, decimals uint8) string {
	denominator := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil)
	whole, fraction := new(big.Int).QuoRem(value, denominator, new(big.Int))
	if fraction.Sign() == 0 {
		return whole.String()
	}
	return whole.String() + "." + strings.TrimRight(fmt.Sprintf("%0*s", decimals, fraction.String()), "0")
}

func main() {
	endpoint := flag.String("rpc", os.Getenv("BSC_RPC_URL"), "BSC JSON-RPC endpoint (or BSC_RPC_URL)")
	txHash := flag.String("tx", caseTx, "transaction hash to investigate")
	flag.Parse()
	if *endpoint == "" {
		fmt.Fprintln(os.Stderr, "set BSC_RPC_URL or pass -rpc (read-only; no wallet key required)")
		os.Exit(2)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	c := rpcClient{endpoint: *endpoint, http: &http.Client{Timeout: 12 * time.Second}}

	var chainID string
	if err := c.call(ctx, "eth_chainId", []any{}, &chainID); err != nil {
		fail(err)
	}
	if !strings.EqualFold(chainID, "0x38") {
		fail(fmt.Errorf("expected BSC chain ID 56 (0x38), got %s", chainID))
	}

	var tx struct {
		From        string `json:"from"`
		To          string `json:"to"`
		Input       string `json:"input"`
		BlockNumber string `json:"blockNumber"`
	}
	if err := c.call(ctx, "eth_getTransactionByHash", []any{*txHash}, &tx); err != nil {
		fail(err)
	}
	if tx.To == "" {
		fail(errors.New("transaction does not target a token contract"))
	}
	var receipt struct {
		Status            string     `json:"status"`
		GasUsed           string     `json:"gasUsed"`
		EffectiveGasPrice string     `json:"effectiveGasPrice"`
		Logs              []eventLog `json:"logs"`
	}
	if err := c.call(ctx, "eth_getTransactionReceipt", []any{*txHash}, &receipt); err != nil {
		fail(err)
	}
	fmt.Printf("Chain: BSC (56)\nTX: %s\nFrom: %s\nTo: %s\nBlock: %s\nStatus: %s\nGas used: %s\nEffective gas price: %s\n", *txHash, tx.From, tx.To, tx.BlockNumber, receipt.Status, receipt.GasUsed, receipt.EffectiveGasPrice)

	officialTransfers := 0
	otherTransfers := 0
	fmt.Println("ERC-20 Transfer logs from the receipt (emitter is the token contract):")
	for _, log := range receipt.Logs {
		from, to, amount, ok := parseTransferEvent(log)
		if !ok {
			continue
		}
		if strings.EqualFold(log.Address, officialUSDT) {
			officialTransfers++
		} else {
			otherTransfers++
		}
		fmt.Printf("  emitter=%s from=%s to=%s amountRaw=%s\n", log.Address, from, to, amount)
	}
	fmt.Printf("Confirmed Transfer log emitters: official-USDT=%d other-contracts=%d\n", officialTransfers, otherTransfers)
	if officialTransfers == 0 {
		fmt.Println("This receipt has no Transfer log emitted by the known BSC USDT token contract.")
	}

	if strings.HasPrefix(strings.ToLower(tx.Input), "0xa9059cbb") && len(tx.Input) == 138 {
		recipient := "0x" + tx.Input[34:74]
		amount, err := uint256Hex("0x" + tx.Input[74:138])
		if err != nil {
			fail(err)
		}
		fmt.Printf("Decoded transfer recipient: %s\nDecoded raw units: %s (decimals not inferred)\n", recipient, amount)
	}

	var bytecode string
	if err := c.call(ctx, "eth_getCode", []any{tx.To, "latest"}, &bytecode); err != nil {
		fail(err)
	}
	if target, ok := minimalProxyTarget(bytecode); ok {
		fmt.Printf("EIP-1167 minimal proxy: YES\nEmbedded implementation: %s\n", target)
	} else {
		fmt.Println("Standard 45-byte EIP-1167 minimal proxy: not detected")
	}

	// State is queried at latest, not at the historical transaction block.
	if len(tx.Input) == 138 && strings.HasPrefix(strings.ToLower(tx.Input), "0xa9059cbb") {
		recipient := "0x" + tx.Input[34:74]
		fmt.Println("Recipient balances at latest block (independent token contracts):")
		for _, address := range []string{tx.To, officialUSDT} {
			callData, err := balanceOfCallData(recipient)
			if err != nil {
				fail(err)
			}
			var raw string
			err = c.call(ctx, "eth_call", []any{map[string]string{"to": address, "data": callData}, "latest"}, &raw)
			if err != nil {
				fmt.Printf("  %s: RPC error: %v\n", address, err)
				continue
			}
			amount, err := uint256Hex(raw)
			if err != nil {
				fmt.Printf("  %s: decode error: %v\n", address, err)
				continue
			}
			fmt.Printf("  %s: %s raw units (18 decimals: %s)\n", address, amount, tokenUnits(amount, 18))
		}
	}
	fmt.Println("Reminder: on-chain balances do not prove USD redemption value; wallet price resolution is off-chain.")
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "error:", err)
	os.Exit(1)
}

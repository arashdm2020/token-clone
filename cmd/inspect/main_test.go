package main

import (
  "math/big"
  "strings"
  "testing"
)

func TestMinimalProxyTarget(t *testing.T) {
  target := "8b4329947e34b6d56d71a3385cac122bade7d78d"
  if len(target) != 40 { t.Fatal("test fixture is not 20 bytes") }
  runtime := "0x" + eip1167Prefix + target + eip1167Suffix
  got, ok := minimalProxyTarget(runtime)
  if !ok || got != "0x" + target { t.Fatalf("target = %s, detected = %v", got, ok) }
  if _, ok := minimalProxyTarget("0x1234"); ok { t.Fatal("unexpected clone match") }
  if _, ok := minimalProxyTarget(runtime+"00"); ok { t.Fatal("unexpected extra bytes accepted") }
}

func TestBalanceCallEncoding(t *testing.T) {
  data, err := balanceOfCallData("0xf32565df6abb4891e5959b7291fecf61a5c6f786")
  if err != nil { t.Fatal(err) }
  if data != "0x70a08231"+strings.Repeat("0", 24)+"f32565df6abb4891e5959b7291fecf61a5c6f786" { t.Fatal(data) }
  if _, err := balanceOfCallData("bad"); err == nil { t.Fatal("invalid address accepted") }
}

func TestTokenUnits(t *testing.T) {
  tests := map[string]string{"0":"0", "1000000000000000000":"1", "30000000000000000000":"30", "1500000000000000001":"1.500000000000000001"}
  for raw, want := range tests {
    v, _ := new(big.Int).SetString(raw, 10)
    if got := tokenUnits(v, 18); got != want { t.Errorf("%s: got %s, want %s", raw, got, want) }
  }
}

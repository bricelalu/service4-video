// Package keystore implements the auth.KeyLookup interface. This implements
// an in-memory keystore for JWT support.
package keystore

import (
	"bytes"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/golang-jwt/jwt/v5"
)

const keyFile = "zarf/keys/private_key.pem"

type KeyStore struct {
	privatePEM map[string]string
}

func New() (*KeyStore, error) {
	file, err := os.Open(keyFile)
	if err != nil {
		return nil, fmt.Errorf("opening key file: %w", err)
	}
	defer file.Close()

	privatePEM, err := io.ReadAll(io.LimitReader(file, 1024*1024))
	if err != nil {
		return nil, fmt.Errorf("reading auth private key: %w", err)
	}

	ks := KeyStore{
		privatePEM: map[string]string{
			"private_key": string(privatePEM),
		},
	}

	return &ks, nil
}

func (k *KeyStore) PrivateKeyPEM(kid string) (pem string, err error) {
	pem, exist := k.privatePEM[kid]
	if !exist {
		return "", errors.New("kid not found")
	}

	return pem, nil
}

func (k *KeyStore) PublicKeyPEM(kid string) (string, error) {
	pemStr, exist := k.privatePEM[kid]
	if !exist {
		return "", errors.New("kid not found")
	}

	privateKey, err := jwt.ParseRSAPrivateKeyFromPEM([]byte(pemStr))
	if err != nil {
		return "", err
	}

	asn1Bytes, err := x509.MarshalPKIXPublicKey(&privateKey.PublicKey)
	if err != nil {
		return "", fmt.Errorf("marshaling public key: %w", err)
	}

	// Construct a PEM block for the public key.
	publicBlock := pem.Block{
		Type:  "PUBLIC KEY",
		Bytes: asn1Bytes,
	}

	var b bytes.Buffer

	// Write the public key to the public key file.
	if err := pem.Encode(&b, &publicBlock); err != nil {
		return "", fmt.Errorf("encoding to public file: %w", err)
	}

	return b.String(), nil
}

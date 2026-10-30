package obsstore

import (
	"context"
	"errors"
	"fmt"
	"io"
	"strings"

	"github.com/huaweicloud/huaweicloud-sdk-go-obs/obs"
)

var ErrUnavailable = errors.New("object storage is not configured")

type Store struct {
	client *obs.ObsClient
	bucket string
	prefix string
}

func New(endpoint, accessKey, secretKey, bucket, prefix string) (*Store, error) {
	if endpoint == "" || accessKey == "" || secretKey == "" || bucket == "" {
		return nil, ErrUnavailable
	}
	client, err := obs.New(accessKey, secretKey, endpoint, obs.WithSignature(obs.SignatureV4))
	if err != nil {
		return nil, fmt.Errorf("create OBS client: %w", err)
	}
	prefix = strings.Trim(prefix, "/")
	return &Store{client: client, bucket: bucket, prefix: prefix}, nil
}

func (s *Store) ObjectKey(familyID, name string) string {
	if s.prefix == "" {
		return familyID + "/" + name
	}
	return s.prefix + "/" + familyID + "/" + name
}

func (s *Store) Put(ctx context.Context, key string, data []byte, contentType string) error {
	input := &obs.PutObjectInput{
		PutObjectBasicInput: obs.PutObjectBasicInput{
			ObjectOperationInput: obs.ObjectOperationInput{
				Bucket: s.bucket, Key: key,
			},
			HttpHeader:    obs.HttpHeader{ContentType: contentType},
			ContentLength: int64(len(data)),
		},
		Body: strings.NewReader(string(data)),
	}
	_, err := s.client.PutObject(input, obs.WithRequestContext(ctx))
	if err != nil {
		return fmt.Errorf("put OBS object: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, key string) (io.ReadCloser, string, int64, error) {
	output, err := s.client.GetObject(&obs.GetObjectInput{
		GetObjectMetadataInput: obs.GetObjectMetadataInput{
			Bucket: s.bucket, Key: key,
		},
	}, obs.WithRequestContext(ctx))
	if err != nil {
		return nil, "", 0, fmt.Errorf("get OBS object: %w", err)
	}
	return output.Body, output.ContentType, output.ContentLength, nil
}

func (s *Store) Delete(ctx context.Context, key string) error {
	_, err := s.client.DeleteObject(&obs.DeleteObjectInput{
		Bucket: s.bucket, Key: key,
	}, obs.WithRequestContext(ctx))
	if err != nil {
		return fmt.Errorf("delete OBS object: %w", err)
	}
	return nil
}

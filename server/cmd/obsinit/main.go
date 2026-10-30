package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/huaweicloud/huaweicloud-sdk-go-obs/obs"
)

func main() {
	ak := strings.TrimSpace(os.Getenv("OBS_ACCESS_KEY_ID"))
	sk := strings.TrimSpace(os.Getenv("OBS_SECRET_KEY"))
	endpoint := strings.TrimSpace(os.Getenv("OBS_ENDPOINT"))
	bucket := strings.TrimSpace(os.Getenv("OBS_BUCKET_NAME"))
	location := strings.TrimSpace(os.Getenv("OBS_LOCATION"))
	if location == "" {
		location = "cn-north-4"
	}
	if ak == "" || sk == "" || endpoint == "" || bucket == "" {
		log.Fatal("OBS_ACCESS_KEY_ID, OBS_SECRET_KEY, OBS_ENDPOINT and OBS_BUCKET_NAME are required")
	}
	client, err := obs.New(ak, sk, endpoint, obs.WithSignature(obs.SignatureV4))
	if err != nil {
		log.Fatalf("create OBS client: %v", err)
	}
	_, err = client.CreateBucket(&obs.CreateBucketInput{
		Bucket: bucket,
		ACL:    obs.AclPrivate,
		BucketLocation: obs.BucketLocation{
			Location: location,
		},
	})
	if err != nil {
		if obsError, ok := err.(obs.ObsError); ok && obsError.StatusCode == 409 {
			fmt.Printf("bucket %s already exists\n", bucket)
			return
		}
		log.Fatalf("create bucket %s: %v", bucket, err)
	}
	fmt.Printf("bucket %s created private in %s\n", bucket, location)
}

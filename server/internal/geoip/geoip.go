// Package geoip performs a small, best-effort lookup of the public IP's
// approximate region for the QR sign-in confirmation screen. It deliberately
// never blocks sign-in: timeout and lookup failures degrade to an unknown city.
package geoip

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

type Location struct {
	IP      string `json:"ip"`
	Country string `json:"country"`
	Region  string `json:"region"`
	City    string `json:"city"`
}

func (location Location) Display() string {
	switch {
	case location.City != "" && location.Region != "" && location.City != location.Region:
		return location.Region + "·" + location.City
	case location.City != "":
		return location.City
	case location.Region != "":
		return location.Region
	case location.Country != "":
		return location.Country
	default:
		return ""
	}
}

type cacheEntry struct {
	location Location
	expires  time.Time
}

type Client struct {
	httpClient *http.Client
	lookupURL  string
	enabled    bool
	mu         sync.Mutex
	cache      map[string]cacheEntry
	now        func() time.Time
}

func New() *Client {
	enabled := strings.TrimSpace(os.Getenv("GEOIP_ENABLED")) != "false"
	endpoint := strings.TrimSpace(os.Getenv("GEOIP_LOOKUP_URL"))
	if endpoint == "" {
		endpoint = "http://ip-api.com/json/%s?lang=zh-CN&fields=status,country,regionName,city"
	}
	transport := &http.Transport{
		DialContext: (&net.Dialer{Timeout: 2 * time.Second}).DialContext,
	}
	return &Client{
		httpClient: &http.Client{Timeout: 3 * time.Second, Transport: transport},
		lookupURL:  endpoint,
		enabled:    enabled,
		cache:      make(map[string]cacheEntry),
		now:        time.Now,
	}
}

func (client *Client) Lookup(ctx context.Context, rawIP string) Location {
	ip := strings.TrimSpace(rawIP)
	location := Location{IP: ip}
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return location
	}
	if isPrivate(parsed) {
		location.Country = "本地"
		location.City = "本地网络"
		return location
	}
	if client == nil || !client.enabled {
		return location
	}

	if cached, ok := client.fromCache(ip); ok {
		return cached
	}

	lookupCtx, cancel := context.WithTimeout(ctx, 3200*time.Millisecond)
	defer cancel()
	requestURL := fmt.Sprintf(client.lookupURL, url.QueryEscape(ip))
	req, err := http.NewRequestWithContext(lookupCtx, http.MethodGet, requestURL, nil)
	if err != nil {
		return location
	}
	response, err := client.httpClient.Do(req)
	if err != nil {
		return location
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return location
	}
	var payload struct {
		Status     string `json:"status"`
		Country    string `json:"country"`
		RegionName string `json:"regionName"`
		City       string `json:"city"`
	}
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return location
	}
	if payload.Status != "" && payload.Status != "success" {
		return location
	}
	location.Country = strings.TrimSpace(payload.Country)
	location.Region = strings.TrimSpace(payload.RegionName)
	location.City = strings.TrimSpace(payload.City)
	if location.Display() != "" && client.now != nil {
		client.mu.Lock()
		client.cache[ip] = cacheEntry{location: location, expires: client.now().Add(24 * time.Hour)}
		client.mu.Unlock()
	}
	return location
}

func (client *Client) fromCache(ip string) (Location, bool) {
	if client.now == nil {
		return Location{}, false
	}
	client.mu.Lock()
	defer client.mu.Unlock()
	entry, ok := client.cache[ip]
	if !ok || !entry.expires.After(client.now()) {
		if ok {
			delete(client.cache, ip)
		}
		return Location{}, false
	}
	return entry.location, true
}

func isPrivate(ip net.IP) bool {
	return ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() || ip.IsUnspecified()
}

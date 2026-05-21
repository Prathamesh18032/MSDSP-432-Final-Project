package gbfs

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const DefaultDiscoveryURL = "https://gbfs.divvybikes.com/gbfs/gbfs.json"

type Client struct {
	discoveryURL *url.URL
	language     string
	httpClient   *http.Client
}

type DiscoveryResponse struct {
	Data map[string]DiscoveryLanguage `json:"data"`
}

type DiscoveryLanguage struct {
	Feeds []Feed `json:"feeds"`
}

type Feed struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type StationInformationResponse struct {
	LastUpdated int64 `json:"last_updated"`
	Data        struct {
		Stations []StationInformation `json:"stations"`
	} `json:"data"`
}

type StationStatusResponse struct {
	LastUpdated int64 `json:"last_updated"`
	Data        struct {
		Stations []StationStatus `json:"stations"`
	} `json:"data"`
}

type StationInformation struct {
	StationID string  `json:"station_id"`
	Name      string  `json:"name"`
	Latitude  float64 `json:"lat"`
	Longitude float64 `json:"lon"`
	Capacity  int     `json:"capacity"`
}

type StationStatus struct {
	StationID         string `json:"station_id"`
	NumBikesAvailable int    `json:"num_bikes_available"`
	NumDocksAvailable int    `json:"num_docks_available"`
	LastReported      int64  `json:"last_reported"`
}

func NewClient(discoveryURL, language string, httpClient *http.Client) (*Client, error) {
	if strings.TrimSpace(discoveryURL) == "" {
		discoveryURL = DefaultDiscoveryURL
	}
	if strings.TrimSpace(language) == "" {
		language = "en"
	}

	parsed, err := url.Parse(discoveryURL)
	if err != nil {
		return nil, fmt.Errorf("parse GBFS discovery URL: %w", err)
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return nil, fmt.Errorf("GBFS discovery URL must include scheme and host")
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 15 * time.Second}
	}

	return &Client{discoveryURL: parsed, language: language, httpClient: httpClient}, nil
}

func (c *Client) FetchStations(ctx context.Context) (StationInformationResponse, StationStatusResponse, error) {
	feeds, err := c.discovery(ctx)
	if err != nil {
		return StationInformationResponse{}, StationStatusResponse{}, err
	}

	infoURL, ok := feeds["station_information"]
	if !ok {
		return StationInformationResponse{}, StationStatusResponse{}, fmt.Errorf("GBFS feed station_information not found")
	}
	statusURL, ok := feeds["station_status"]
	if !ok {
		return StationInformationResponse{}, StationStatusResponse{}, fmt.Errorf("GBFS feed station_status not found")
	}

	var info StationInformationResponse
	if err := c.get(ctx, infoURL, &info); err != nil {
		return StationInformationResponse{}, StationStatusResponse{}, fmt.Errorf("fetch GBFS station_information: %w", err)
	}

	var status StationStatusResponse
	if err := c.get(ctx, statusURL, &status); err != nil {
		return StationInformationResponse{}, StationStatusResponse{}, fmt.Errorf("fetch GBFS station_status: %w", err)
	}
	return info, status, nil
}

func (c *Client) discovery(ctx context.Context) (map[string]string, error) {
	var response DiscoveryResponse
	if err := c.get(ctx, c.discoveryURL.String(), &response); err != nil {
		return nil, fmt.Errorf("fetch GBFS discovery: %w", err)
	}

	languageFeeds, ok := response.Data[c.language]
	if !ok {
		return nil, fmt.Errorf("GBFS language %q not found", c.language)
	}

	feeds := map[string]string{}
	for _, feed := range languageFeeds.Feeds {
		if feed.Name != "" && feed.URL != "" {
			feeds[feed.Name] = feed.URL
		}
	}
	return feeds, nil
}

func (c *Client) get(ctx context.Context, requestURL string, target any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return fmt.Errorf("build GBFS request: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("call GBFS: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("GBFS returned status %d", resp.StatusCode)
	}
	if err := json.NewDecoder(resp.Body).Decode(target); err != nil {
		return fmt.Errorf("decode GBFS response: %w", err)
	}
	return nil
}

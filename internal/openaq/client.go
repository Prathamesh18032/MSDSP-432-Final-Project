package openaq

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const DefaultBaseURL = "https://api.openaq.org"

type Client struct {
	baseURL    *url.URL
	apiKey     string
	httpClient *http.Client
}

type Location struct {
	ID          int          `json:"id"`
	Name        *string      `json:"name"`
	Coordinates Coordinates  `json:"coordinates"`
	Sensors     []SensorMeta `json:"sensors"`
}

type SensorMeta struct {
	ID          int         `json:"id"`
	Name        string      `json:"name"`
	Parameter   Parameter   `json:"parameter"`
	Units       string      `json:"units"`
	Coordinates Coordinates `json:"coordinates"`
}

type Parameter struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`
	Units       string `json:"units"`
	DisplayName string `json:"displayName"`
}

type LatestMeasurement struct {
	DateTime    DateTimeObject `json:"datetime"`
	Value       float64        `json:"value"`
	Coordinates Coordinates    `json:"coordinates"`
	SensorsID   int            `json:"sensorsId"`
	LocationID  int            `json:"locationsId"`
}

type Coordinates struct {
	Latitude  *float64 `json:"latitude"`
	Longitude *float64 `json:"longitude"`
}

type DateTimeObject struct {
	UTC   time.Time `json:"utc"`
	Local time.Time `json:"local"`
}

func NewClient(baseURL, apiKey string, httpClient *http.Client) (*Client, error) {
	if strings.TrimSpace(apiKey) == "" {
		return nil, fmt.Errorf("OPENAQ_API_KEY is required")
	}
	if strings.TrimSpace(baseURL) == "" {
		baseURL = DefaultBaseURL
	}

	parsed, err := url.Parse(strings.TrimRight(baseURL, "/"))
	if err != nil {
		return nil, fmt.Errorf("parse OpenAQ base URL: %w", err)
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return nil, fmt.Errorf("OpenAQ base URL must include scheme and host")
	}

	if httpClient == nil {
		httpClient = &http.Client{Timeout: 15 * time.Second}
	}

	return &Client{baseURL: parsed, apiKey: apiKey, httpClient: httpClient}, nil
}

func (c *Client) ListLocations(ctx context.Context, coordinates string, radiusMeters, limit int) ([]Location, error) {
	values := url.Values{}
	values.Set("coordinates", coordinates)
	values.Set("radius", strconv.Itoa(radiusMeters))
	values.Set("limit", strconv.Itoa(limit))
	values.Set("page", "1")

	var response struct {
		Results []Location `json:"results"`
	}
	if err := c.get(ctx, "/v3/locations", values, &response); err != nil {
		return nil, err
	}
	return response.Results, nil
}

func (c *Client) ListSensors(ctx context.Context, locationID int) ([]SensorMeta, error) {
	var response struct {
		Results []SensorMeta `json:"results"`
	}
	path := fmt.Sprintf("/v3/locations/%d/sensors", locationID)
	if err := c.get(ctx, path, nil, &response); err != nil {
		return nil, err
	}
	return response.Results, nil
}

func (c *Client) LatestByLocation(ctx context.Context, locationID int) ([]LatestMeasurement, error) {
	values := url.Values{}
	values.Set("limit", "100")
	values.Set("page", "1")

	var response struct {
		Results []LatestMeasurement `json:"results"`
	}
	path := fmt.Sprintf("/v3/locations/%d/latest", locationID)
	if err := c.get(ctx, path, values, &response); err != nil {
		return nil, err
	}
	return response.Results, nil
}

func (c *Client) get(ctx context.Context, path string, values url.Values, target any) error {
	requestURL := c.baseURL.ResolveReference(&url.URL{Path: path})
	if values != nil {
		requestURL.RawQuery = values.Encode()
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL.String(), nil)
	if err != nil {
		return fmt.Errorf("build OpenAQ request: %w", err)
	}
	req.Header.Set("X-API-Key", c.apiKey)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("call OpenAQ %s: %w", path, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("OpenAQ %s returned status %d", path, resp.StatusCode)
	}

	if err := json.NewDecoder(resp.Body).Decode(target); err != nil {
		return fmt.Errorf("decode OpenAQ %s response: %w", path, err)
	}
	return nil
}

package openmeteo

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

const DefaultBaseURL = "https://api.open-meteo.com"

type Client struct {
	baseURL    *url.URL
	httpClient *http.Client
}

type CurrentResponse struct {
	Latitude     float64        `json:"latitude"`
	Longitude    float64        `json:"longitude"`
	CurrentUnits CurrentUnits   `json:"current_units"`
	Current      CurrentWeather `json:"current"`
}

type CurrentUnits struct {
	Time             string `json:"time"`
	Temperature2M    string `json:"temperature_2m"`
	RelativeHumidity string `json:"relative_humidity_2m"`
	WindSpeed10M     string `json:"wind_speed_10m"`
	Precipitation    string `json:"precipitation"`
}

type CurrentWeather struct {
	Time             string  `json:"time"`
	Temperature2M    float64 `json:"temperature_2m"`
	RelativeHumidity float64 `json:"relative_humidity_2m"`
	WindSpeed10M     float64 `json:"wind_speed_10m"`
	Precipitation    float64 `json:"precipitation"`
}

func NewClient(baseURL string, httpClient *http.Client) (*Client, error) {
	if strings.TrimSpace(baseURL) == "" {
		baseURL = DefaultBaseURL
	}

	parsed, err := url.Parse(strings.TrimRight(baseURL, "/"))
	if err != nil {
		return nil, fmt.Errorf("parse Open-Meteo base URL: %w", err)
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return nil, fmt.Errorf("Open-Meteo base URL must include scheme and host")
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 15 * time.Second}
	}

	return &Client{baseURL: parsed, httpClient: httpClient}, nil
}

func (c *Client) Current(ctx context.Context, latitude, longitude float64) (CurrentResponse, error) {
	values := url.Values{}
	values.Set("latitude", strconv.FormatFloat(latitude, 'f', -1, 64))
	values.Set("longitude", strconv.FormatFloat(longitude, 'f', -1, 64))
	values.Set("current", "temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation")
	values.Set("timezone", "UTC")

	requestURL := c.baseURL.ResolveReference(&url.URL{Path: "/v1/forecast"})
	requestURL.RawQuery = values.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL.String(), nil)
	if err != nil {
		return CurrentResponse{}, fmt.Errorf("build Open-Meteo request: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return CurrentResponse{}, fmt.Errorf("call Open-Meteo: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return CurrentResponse{}, fmt.Errorf("Open-Meteo returned status %d", resp.StatusCode)
	}

	var target CurrentResponse
	if err := json.NewDecoder(resp.Body).Decode(&target); err != nil {
		return CurrentResponse{}, fmt.Errorf("decode Open-Meteo response: %w", err)
	}
	return target, nil
}

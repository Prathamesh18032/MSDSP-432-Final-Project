package usgs

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const DefaultBaseURL = "https://waterservices.usgs.gov"

type Client struct {
	baseURL    *url.URL
	httpClient *http.Client
}

type InstantaneousResponse struct {
	Value struct {
		TimeSeries []TimeSeries `json:"timeSeries"`
	} `json:"value"`
}

type TimeSeries struct {
	SourceInfo SourceInfo `json:"sourceInfo"`
	Variable   Variable   `json:"variable"`
	Values     []Values   `json:"values"`
}

type SourceInfo struct {
	SiteName    string      `json:"siteName"`
	SiteCode    []Code      `json:"siteCode"`
	GeoLocation GeoLocation `json:"geoLocation"`
}

type GeoLocation struct {
	GeogLocation GeogLocation `json:"geogLocation"`
}

type GeogLocation struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Variable struct {
	VariableCode []Code `json:"variableCode"`
	VariableName string `json:"variableName"`
	Unit         Unit   `json:"unit"`
}

type Unit struct {
	UnitCode string `json:"unitCode"`
}

type Values struct {
	Value []MeasurementValue `json:"value"`
}

type MeasurementValue struct {
	Value    string    `json:"value"`
	DateTime time.Time `json:"dateTime"`
}

type Code struct {
	Value string `json:"value"`
}

func NewClient(baseURL string, httpClient *http.Client) (*Client, error) {
	if strings.TrimSpace(baseURL) == "" {
		baseURL = DefaultBaseURL
	}

	parsed, err := url.Parse(strings.TrimRight(baseURL, "/"))
	if err != nil {
		return nil, fmt.Errorf("parse USGS base URL: %w", err)
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return nil, fmt.Errorf("USGS base URL must include scheme and host")
	}
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 15 * time.Second}
	}

	return &Client{baseURL: parsed, httpClient: httpClient}, nil
}

func (c *Client) InstantaneousValues(ctx context.Context, siteIDs, parameterCodes string) (InstantaneousResponse, error) {
	values := url.Values{}
	values.Set("format", "json")
	values.Set("sites", siteIDs)
	values.Set("parameterCd", parameterCodes)
	values.Set("siteStatus", "all")

	requestURL := c.baseURL.ResolveReference(&url.URL{Path: "/nwis/iv/"})
	requestURL.RawQuery = values.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL.String(), nil)
	if err != nil {
		return InstantaneousResponse{}, fmt.Errorf("build USGS request: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return InstantaneousResponse{}, fmt.Errorf("call USGS: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return InstantaneousResponse{}, fmt.Errorf("USGS returned status %d", resp.StatusCode)
	}

	var target InstantaneousResponse
	if err := json.NewDecoder(resp.Body).Decode(&target); err != nil {
		return InstantaneousResponse{}, fmt.Errorf("decode USGS response: %w", err)
	}
	return target, nil
}

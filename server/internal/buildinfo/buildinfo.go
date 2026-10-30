package buildinfo

// These values are overridden with -ldflags at build time. The defaults make
// local `go run` output explicit instead of pretending to be a release.
var (
	Version   = "dev"
	Commit    = "unknown"
	BuildTime = "unknown"
)

const (
	Service    = "family-tree-api"
	APIVersion = "v1"
)

type Info struct {
	Service    string `json:"service"`
	Version    string `json:"version"`
	Commit     string `json:"commit"`
	BuildTime  string `json:"buildTime"`
	APIVersion string `json:"apiVersion"`
}

func Current() Info {
	return Info{
		Service:    Service,
		Version:    Version,
		Commit:     Commit,
		BuildTime:  BuildTime,
		APIVersion: APIVersion,
	}
}

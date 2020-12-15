package healthcheck

import (
	"github.com/Peripli/service-manager/pkg/health"
	"github.com/Peripli/service-manager/pkg/types"
)

func CheckPlatformsState(platforms []*types.Platform, fatal func(*types.Platform) bool) (map[string]*health.Health, int, int) {
	details := make(map[string]*health.Health)
	inactivePlatforms := 0
	fatalInactivePlatforms := 0
	for _, platform := range platforms {
		var status health.Status
		if platform.Active {
			status = health.StatusUp
		} else {
			status = health.StatusDown
		}
		details[platform.Name] = health.New().WithDetail("type", platform.Type).WithStatus(status)

		if fatal != nil && fatal(platform) {
			fatalInactivePlatforms++
		}
		inactivePlatforms++

	}
	return details, inactivePlatforms, fatalInactivePlatforms

}
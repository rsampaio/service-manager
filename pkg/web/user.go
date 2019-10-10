/*
 * Copyright 2018 The Service Manager Authors
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

package web

// AuthenticationType specifies the authentication type that is stored in the user context
type AuthenticationType int

var authenticationTypes = []string{"Basic", "Bearer"}

const (
	Basic AuthenticationType = iota
	Bearer
)

// String implements Stringer and converts the decision to human-readable value
func (a AuthenticationType) String() string {
	return authenticationTypes[a]
}

// AccessLevel specifies the access level privileges that are stored in the user context
type AccessLevel int

var levels = []string{"DefaultAccess", "GlobalAccess", "SingleTenantAccess", "AllTenantAccess"}

const (
	//DefaultAccess is the default value for access level - it is used when a component does not expliciting set an access level
	DefaultAccess AccessLevel = iota

	// GlobalAccess means access was granted to manage global resources (such resources are not scoped or associated with tenant.
	// Such access might be granted to systems that need to manage global resources	GlobalAccess AccessLevel = iota
	GlobalAccess

	// TenantAccess means access was granted to manage the tenant's own resources. Such access might be granted to a user
	// so the he can manage his own data
	TenantAccess

	// AllTenantAccess means access was granted to manage the resources of all tenants. Such access might be granted
	// to systems that have to manage data across multiple tenants
	AllTenantAccess
)

// String implements Stringer and converts the decision to human-readable value
func (a AccessLevel) String() string {
	return levels[a]
}

// UserContext holds the information for the current user
type UserContext struct {
	// Data unmarshals the additional user context details into the specified struct
	Data func(data interface{}) error
	// AuthenticationType is the authentication type for this user context
	AuthenticationType AuthenticationType
	// Name is the name of the authenticated user
	Name string
	// AccessLevel is the user access level
	AccessLevel AccessLevel
}

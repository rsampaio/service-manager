package cascade_test

import (
	"context"
	"github.com/Peripli/service-manager/pkg/query"
	"github.com/Peripli/service-manager/pkg/types"
	"github.com/Peripli/service-manager/test/common"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"net/http"
	"time"
)

var _ = Describe("cascade operations", func() {
	JustBeforeEach(func() {
		initTenantResources(true)
	})

	Context("cleanup", func() {
		It("finished tree should be deleted", func() {
			rootID := triggerCascadeOperation(context.Background(), types.TenantType, tenantID)
			common.VerifyOperationExists(ctx, "", common.OperationExpectations{
				Category:          types.DELETE,
				State:             types.SUCCEEDED,
				ResourceType:      types.TenantType,
				Reschedulable:     false,
				DeletionScheduled: false,
			})
			ctx.Maintainer.CleanupFinishedCascadeOperations()
			count, err := ctx.SMRepository.Count(
				context.Background(),
				types.OperationType,
				queryForOperationsInTheSameTree(rootID))
			Expect(err).NotTo(HaveOccurred())
			Expect(count).To(Equal(0))
		})

		It("multiple finished trees should be deleted", func() {
			rootID := triggerCascadeOperation(context.Background(), types.TenantType, tenantID)
			triggerCascadeOperation(context.Background(), types.PlatformType, platformID)
			triggerCascadeOperation(context.Background(), types.ServiceBrokerType, brokerID)

			Eventually(func() int {
				count, err := ctx.SMRepository.Count(
					context.Background(),
					types.OperationType,
					query.ByField(query.InOperator, "cascade_root_id", rootID, "root1", "root2"),
					query.ByField(query.EqualsOrNilOperator, "parent_id", ""),
					querySucceeded)
				Expect(err).NotTo(HaveOccurred())
				return count
			}, actionTimeout*20+pollCascade*20).Should(Equal(1))

			ctx.Maintainer.CleanupFinishedCascadeOperations()
			count, err := ctx.SMRepository.Count(
				context.Background(),
				types.OperationType,
				query.ByField(query.InOperator, "cascade_root_id", rootID, "root1", "root2"),
				query.ByField(query.EqualsOrNilOperator, "parent_id", ""))
			Expect(err).NotTo(HaveOccurred())
			Expect(count).To(Equal(0))
		})

		It("in_progress tree should not be deleted", func() {
			registerBindingLastOPHandlers(brokerServer, http.StatusOK, types.IN_PROGRESS)
			rootID := triggerCascadeOperation(context.Background(), types.TenantType, tenantID)
			common.VerifyOperationExists(ctx, "", common.OperationExpectations{
				Category:          types.DELETE,
				State:             types.PENDING,
				ResourceType:      types.TenantType,
				Reschedulable:     false,
				DeletionScheduled: false,
			})
			ctx.Maintainer.CleanupFinishedCascadeOperations()
			count, err := ctx.SMRepository.Count(
				context.Background(),
				types.OperationType,
				queryForOperationsInTheSameTree(rootID))
			Expect(err).NotTo(HaveOccurred())
			Expect(count).To(Equal(11))
		})

		It("not cascade tree should not be deleted", func() {
			op := types.Operation{
				Base: types.Base{
					ID:        "opid",
					CreatedAt: time.Now(),
					UpdatedAt: time.Now(),
					Ready:     true,
				},
				Description:  "bla",
				ResourceID:   osbInstanceID,
				State:        types.IN_PROGRESS,
				Type:         types.DELETE,
				ResourceType: types.ServiceInstanceType,
			}
			_, err := ctx.SMRepository.Create(context.Background(), &op)
			Expect(err).NotTo(HaveOccurred())
			common.VerifyOperationExists(ctx, "", common.OperationExpectations{
				Category:          types.DELETE,
				State:             types.IN_PROGRESS,
				ResourceType:      types.ServiceInstanceType,
				Reschedulable:     false,
				DeletionScheduled: false,
			})
			ctx.Maintainer.CleanupFinishedCascadeOperations()
			count, err := ctx.SMRepository.Count(
				context.Background(),
				types.OperationType, []query.Criterion{
					query.ByField(query.InOperator, "resource_id", osbInstanceID),
					query.ByField(query.EqualsOrNilOperator, "cascade_root_id", ""),
					query.ByField(query.EqualsOperator, "state", string(types.IN_PROGRESS)),
				}...)
			Expect(err).NotTo(HaveOccurred())
			Expect(count).To(Equal(1))
		})
	})
})
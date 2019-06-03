// Code generated by counterfeiter. DO NOT EDIT.
package securityfakes

import (
	"context"
	"sync"

	"github.com/Peripli/service-manager/pkg/security"
)

type FakeKeySetter struct {
	SetEncryptionKeyStub        func(context.Context, []byte) error
	setEncryptionKeyMutex       sync.RWMutex
	setEncryptionKeyArgsForCall []struct {
		arg1 context.Context
		arg2 []byte
	}
	setEncryptionKeyReturns struct {
		result1 error
	}
	setEncryptionKeyReturnsOnCall map[int]struct {
		result1 error
	}
	invocations      map[string][][]interface{}
	invocationsMutex sync.RWMutex
}

func (fake *FakeKeySetter) SetEncryptionKey(arg1 context.Context, arg2 []byte) error {
	var arg2Copy []byte
	if arg2 != nil {
		arg2Copy = make([]byte, len(arg2))
		copy(arg2Copy, arg2)
	}
	fake.setEncryptionKeyMutex.Lock()
	ret, specificReturn := fake.setEncryptionKeyReturnsOnCall[len(fake.setEncryptionKeyArgsForCall)]
	fake.setEncryptionKeyArgsForCall = append(fake.setEncryptionKeyArgsForCall, struct {
		arg1 context.Context
		arg2 []byte
	}{arg1, arg2Copy})
	fake.recordInvocation("SetEncryptionKey", []interface{}{arg1, arg2Copy})
	fake.setEncryptionKeyMutex.Unlock()
	if fake.SetEncryptionKeyStub != nil {
		return fake.SetEncryptionKeyStub(arg1, arg2)
	}
	if specificReturn {
		return ret.result1
	}
	fakeReturns := fake.setEncryptionKeyReturns
	return fakeReturns.result1
}

func (fake *FakeKeySetter) SetEncryptionKeyCallCount() int {
	fake.setEncryptionKeyMutex.RLock()
	defer fake.setEncryptionKeyMutex.RUnlock()
	return len(fake.setEncryptionKeyArgsForCall)
}

func (fake *FakeKeySetter) SetEncryptionKeyCalls(stub func(context.Context, []byte) error) {
	fake.setEncryptionKeyMutex.Lock()
	defer fake.setEncryptionKeyMutex.Unlock()
	fake.SetEncryptionKeyStub = stub
}

func (fake *FakeKeySetter) SetEncryptionKeyArgsForCall(i int) (context.Context, []byte) {
	fake.setEncryptionKeyMutex.RLock()
	defer fake.setEncryptionKeyMutex.RUnlock()
	argsForCall := fake.setEncryptionKeyArgsForCall[i]
	return argsForCall.arg1, argsForCall.arg2
}

func (fake *FakeKeySetter) SetEncryptionKeyReturns(result1 error) {
	fake.setEncryptionKeyMutex.Lock()
	defer fake.setEncryptionKeyMutex.Unlock()
	fake.SetEncryptionKeyStub = nil
	fake.setEncryptionKeyReturns = struct {
		result1 error
	}{result1}
}

func (fake *FakeKeySetter) SetEncryptionKeyReturnsOnCall(i int, result1 error) {
	fake.setEncryptionKeyMutex.Lock()
	defer fake.setEncryptionKeyMutex.Unlock()
	fake.SetEncryptionKeyStub = nil
	if fake.setEncryptionKeyReturnsOnCall == nil {
		fake.setEncryptionKeyReturnsOnCall = make(map[int]struct {
			result1 error
		})
	}
	fake.setEncryptionKeyReturnsOnCall[i] = struct {
		result1 error
	}{result1}
}

func (fake *FakeKeySetter) Invocations() map[string][][]interface{} {
	fake.invocationsMutex.RLock()
	defer fake.invocationsMutex.RUnlock()
	fake.setEncryptionKeyMutex.RLock()
	defer fake.setEncryptionKeyMutex.RUnlock()
	copiedInvocations := map[string][][]interface{}{}
	for key, value := range fake.invocations {
		copiedInvocations[key] = value
	}
	return copiedInvocations
}

func (fake *FakeKeySetter) recordInvocation(key string, args []interface{}) {
	fake.invocationsMutex.Lock()
	defer fake.invocationsMutex.Unlock()
	if fake.invocations == nil {
		fake.invocations = map[string][][]interface{}{}
	}
	if fake.invocations[key] == nil {
		fake.invocations[key] = [][]interface{}{}
	}
	fake.invocations[key] = append(fake.invocations[key], args)
}

var _ security.KeySetter = new(FakeKeySetter)
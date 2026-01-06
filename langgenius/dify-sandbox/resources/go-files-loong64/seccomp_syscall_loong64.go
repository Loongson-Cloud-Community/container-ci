//go:build linux && loong64

package lib

import "syscall"

const (
	SYS_SECCOMP = syscall.SYS_SECCOMP
)

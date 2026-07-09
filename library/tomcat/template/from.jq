# This file expects "env.variant" (e.g., "jdk8/debian-forky")
# and defines "from" function used in Dockerfile.template

def java_dir:
	env.variant | split("/")[0] # "jdk8", "jdk11", etc.
;
def java_version:
	java_dir | ltrimstr("jre") | ltrimstr("jdk") # "8", "11", etc.
;
def java_variant:
	java_dir | rtrimstr(java_version) # "jdk", "jre"
;
def vendor_variant:
	env.variant | split("/")[1] # "debian-forky", "temurin", etc.
;
def from:
	vendor_variant
	| if test("^debian-forky") then
		"lcr.loongnix.cn/library/openjdk:" + java_version + "-debian-forky"
	elif test("^temurin") then
		"lcr.loongnix.cn/library/eclipse-temurin:" + java_version + "-" + java_variant
	else
		error("unknown vendor variant: " + .)
	end
;

fetch_ruby_dist_info(){
	local version=$1
	wget -qO- https://github.com/ruby/www.ruby-lang.org/raw/master/_data/releases.yml | \
	yq -r '@json' | \
	jq -cr \
		--arg version "$version" \
		'map(
			select(.version==($version))
		) | first'
}


gen_version_json(){
	local version=$1
	local ruby_dist_info=$(fetch_ruby_dist_info "$version")
	local rust=$(jq -cr '{rust: .}' json/rust.json)
	local rustup=$(jq -cr '{rustup: .}' json/rustup.json)
	local variants=$(jq -cr '{variants: .}' json/variants.json)
    jq -ncr \
		--arg version $version \
        --argjson ruby_dist_info $ruby_dist_info \
        --argjson rust $rust \
        --argjson rustup $rustup \
        --argjson variants $variants \
        '($ruby_dist_info) + ($rust) |
			. + ($rustup) |
			. + ($variants) |
			{($version): .}
		'

}

append_version(){
	version=$1
	version_json=$(gen_version_json $version)
	versions_json=$(jq -cr '.' versions.json)
	jq -n \
		--argjson version_json $version_json \
		--argjson versions_json $versions_json \
		'($version_json) + ($versions_json)' >versions.json

}

set -x;

append_version "$1"


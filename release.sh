#!/bin/sh

deploy()
{
	local from_deploy="$3"
	local from_root="$2"
	local out=$(mktemp)
	local repo="$1"
	local status
	local to_cmd="$6"
	local to_host="$4"
	local to_path="$5"

	(
		cd "$repo" &&
		git fetch -aq &&
		git diff --quiet HEAD origin/master ||
		(
			git reset -q --hard origin/master &&
			cd "$from_root" &&
			( test '!' -f setup.sh || sh setup.sh > /dev/null ) &&
			tar cCO "$from_deploy" . |
			ssh -q "$to_host" "tar xC '$to_path' -f - && ${to_cmd:-true}"
		)
	) > "$out" 2>&1

	if [ "$?" -ne 0 ]; then
		mail -r foab@bidtorrent.io -s "The FOAB is broken! ($repo)" bidtorrent@lists.criteo.net < "$out"
	fi

	rm "$out"

	status=$(cd "$repo" && git log -1 --oneline)

	echo "$repo: $status"
}

#	deploy <repo>			<from_root>			<from_deploy> <to_host>		<to_path>	<to_cmd>
(
	deploy api				.					src		nginx@bidtorrent.io	/var/www/io.bidtorrent.api &&
	deploy bidder-criteo	.					src		nginx@bidtorrent.io	/var/www/io.bidtorrent.test &&
	deploy client-js		.					build	nginx@bidtorrent.io	/var/www/io.bidtorrent &&
	deploy configuration-ui	configuration-ui	bin		nginx@bidtorrent.io	/var/www/io.bidtorrent.www &&
	deploy server			.					nginx	root@bidtorrent.io	/etc/nginx	'service nginx reload'
	deploy track			.					src		nginx@bidtorrent.io	/var/www/io.bidtorrent.log
) |
ssh -q www-data@sandstone 'cat > www/io.bidtorrent.doc/foab.txt'

#!/bin/sh

deploy()
{
	local command="$5"
	local host="$3"
	local out=$(mktemp)
	local repo="$1"
	local source="$2"
	local status
	local target="$4"

	(
		cd "$repo" &&
		git fetch -aq &&
		git diff --quiet HEAD origin/master ||
		(
			git reset -q --hard origin/master &&
			cd "$from_root" &&
			( test '!' -f setup.sh || sh setup.sh > /dev/null ) &&
			tar cCO "$source" . |
			ssh -q "$host" "tar xC '$target' -f - && ${command:-true}"
		)
	) > "$out" 2>&1

	if [ "$?" -ne 0 ]; then
		mail -r foab@bidtorrent.io -s "The FOAB is broken! ($repo)" bidtorrent@lists.criteo.net < "$out"
	fi

	rm "$out"

	status=$(cd "$repo" && git log -1 --oneline)

	echo "$repo: $status"
}

#	deploy <repo>			<src>	<host>		<target>	<command>
(
	deploy api				src		nginx@bidtorrent.io	/var/www/io.bidtorrent.api &&
	deploy bidder-criteo	src		nginx@bidtorrent.io	/var/www/io.bidtorrent.test &&
	deploy client-js		build	nginx@bidtorrent.io	/var/www/io.bidtorrent &&
	deploy configuration-ui	bin		nginx@bidtorrent.io	/var/www/io.bidtorrent.www &&
	deploy server			nginx	root@bidtorrent.io	/etc/nginx	'service nginx reload'
) |
ssh -q www-data@sandstone 'cat > www/io.bidtorrent.doc/foab.txt'

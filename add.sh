#!/usr/bin/env bash

set -e

APP="$1"
VERSION="$2"
DISTFOLDER="$3"

docker build -t apk-deploy:local .
rm -rf edge
mkdir -p "./edge/main/aarch64" "./edge/main/x86_64"

cat _redirects | grep 'https' | awk '{print $2}' | while read link; do
	filename=$(basename "$link")
	if (echo "$filename" | grep -q "arm64"); then
		curl -L -o "./edge/main/aarch64/$filename" "$link"
	else
		curl -L -o "./edge/main/x86_64/$filename" "$link"
	fi
done

ls "$DISTFOLDER" | grep '.apk' | while read file; do
	if (echo "$file" | grep -q "arm64"); then
		cp "$DISTFOLDER/$file" edge/main/aarch64/
		echo "/edge/main/aarch64/${file} https://github.com/dustinblackman/${APP}/releases/download/v${VERSION}/${file} 302" >>_redirects
	else
		cp "$DISTFOLDER/$file" edge/main/x86_64/
		echo "/edge/main/x86_64/${file} https://github.com/dustinblackman/${APP}/releases/download/v${VERSION}/${file} 302" >>_redirects
	fi
done

ls ./edge/main | while read arch; do
	(
		cd "./edge/main/$arch"
		docker run --rm -t -e "SIGN_KEY=$(cat ~/.gpg/apk@apk.dustinblackman.com-658c5a5b.rsa | base64)" -v "$PWD:/project" -w /project apk-deploy:local bash -c \
			'apk index -vU -o APKINDEX.tar.gz *.apk && echo $SIGN_KEY | base64 -d >/tmp/apk@apk.dustinblackman.com-658c5a5b.rsa && abuild-sign -k /tmp/apk@apk.dustinblackman.com-658c5a5b.rsa APKINDEX.tar.gz'
	)
done

rm ./edge/main/*/*.apk

git add _redirects
git commit -m "add $APP $VERSION"
git push

npx wrangler pages deploy --project-name apk .

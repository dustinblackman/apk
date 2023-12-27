#!/usr/bin/env bash

set -e

APP="$1"
VERSION="$2"
DISTFOLDER="$3"

docker build -t apk-deploy:local .
rm -rf apk
mkdir -p "./apk/edge/main/aarch64" "./apk/edge/main/x86_64"

cat _redirects | grep 'https' | awk '{print $2}' | while read link; do
	filename=$(basename "$link")
	if (echo "$filename" | grep -q "arm64"); then
		curl -L -o "./apk/edge/main/aarch64/$filename" "$link"
	else
		curl -L -o "./apk/edge/main/x86_64/$filename" "$link"
	fi
done

ls "$DISTFOLDER" | grep '.apk' | while read file; do
	if (echo "$file" | grep -q "arm64"); then
		cp "$DISTFOLDER/$file" apk/edge/main/aarch64/
		echo "apk/edge/main/aarch64/${file} https://github.com/dustinblackman/${APP}/releases/download/v${VERSION}/${file} 302" >>_redirects
	else
		cp "$DISTFOLDER/$file" apk/edge/main/x86_64/
		echo "apk/edge/main/x86_64/${file} https://github.com/dustinblackman/${APP}/releases/download/v${VERSION}/${file} 302" >>_redirects
	fi
done

ls ./apk/edge/main | while read arch; do
	(
		cd "./apk/edge/main/$arch"
		docker run --rm -t -e "SIGN_KEY=$(cat ~/.gpg/alpine-linux-apk.key | base64)" -v "$PWD:/project" -w /project apk-deploy:local bash -c \
			'apk index -vU -o APKINDEX.tar.gz *.apk && echo $SIGN_KEY | base64 -d >/tmp/key && abuild-sign -k /tmp/key APKINDEX.tar.gz'
	)
done

rm ./apk/edge/main/*/*.apk
npx wrangler pages deploy --project-name apk .
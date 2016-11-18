#!/bin/bash

saved="`pwd`"
cd "`dirname \"$0\"`" >/dev/null
app_home="`pwd -P`"
cd "$saved" >/dev/null

sketchtool=sketchtool/bin/sketchtool
vdtool="$app_home/vd-tool/bin/vd-tool"

destDir="$1"
shift

generateForASketch() {
    srcFile="$1"

    destDirForASketch="$destDir/$srcFile"

    mkdir -p "$destDirForASketch"
    ${sketchtool} export artboards "$srcFile" --output="$destDirForASketch"
}

generateIndex() {
    srcFile="$1"

    cd "$destDir/$srcFile"

    cat > index.html <<EOF
<html><head><title>$srcFile</title></head>
<body><h1>Artboards of $srcFile</h1>
EOF

    for pngFile in *.png ; do
        cat >> index.html <<EOF
<h2><a name="$pngFile" href="#$pngFile">$pngFile</a></h2>
<img src="$pngFile">
EOF
    done

    cat >> index.html <<EOF
</body></html>
EOF
    cd -
}

generateMetaIndex() {
    cd "$destDir"

    cat > index.html <<EOF
<html><head><title>Aya:$CIRCLE_SHA1</title></head>
<body><h1>Artboards of $CIRCLE_SHA1</h1>
<a href="https://github.com/quipper/aya-mobile-design/commit/$CIRCLE_SHA1">change</a></p>
<ul>
EOF

    for pngDir in *.sketch ; do
        cat >> index.html <<EOF
<li><a href="$pngDir/index.html">$pngDir</a>
EOF
    done

    cat >> index.html <<EOF
</body></html>
EOF
    cd -
}

exportIcons() {
    src="$1"
    mkdir -p "$destDir/icons"
    ${sketchtool} export slices "$src" --output="$destDir/icons"
    ${sketchtool} export slices "$src" --formats=svg --output="$destDir/icons"
    ${vdtool} -c -in "$destDir/icons"

    (cd "$destDir/icons"; zip ../icons.zip *)
    rm -r "$destDir/icons"
}

for file in *.sketch ; do
    generateForASketch "$file"
    generateIndex "$file"
done

generateMetaIndex
exportIcons sketch/images.sketch

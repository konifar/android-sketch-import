#!/bin/bash -ue

# Usage: sketch_import.sh ${circle_ci_token} ${BUILD_NO} ${GITHUB_TOKEN}

dest_dir='../../app/src/main/res'
github_api_pulls_endpoint='https://api.github.com/repos/konifar/android-sketch-import/pulls'

distributeFile() {
    local src_dir="$1"
    local dest_dir="$2"
    local modifier="$3"
    local ext="$4"

    mkdir -p "$dest_dir"

    for file in "$src_dir/"*"$modifier"."$ext" ; do
        [[ -f "$file" ]] || continue
        dest_file=`basename $file`
        dest_file="${dest_file/$modifier/}"
        expr "$dest_file" : "^[a-zA-Z_0-9]*\.$ext$" >& /dev/null || {
            echo "Illegal file name: $file" >&2
            exit 1
        }
        mv "$file" "$dest_dir/$dest_file"
    done
}

filterResources() {
    local src_dir="$1"

    sed 's/.*/rm -f &.{png,svg,xml}; rm -f &@*.png/' black_list_for_drawable | (cd "$src_dir"; /bin/bash -x)
    sed 's/.*/rm -f &.xml/' black_list_for_vector_drawable | (cd "$src_dir"; /bin/bash -x)

    for file in "$src_dir/"*.xml ; do
        basename=`basename $file`
        filename="${basename%.*}"
        rm -f "$src_dir/$filename".png "$src_dir/$filename"@*.png
        mv "$src_dir/$basename" "$src_dir/vec_$basename"
    done
}


circle_ci_token="$1"
build_no="$2"
github_token="$3"
base_branch='master'
branch_name="sketch_images_import"

rm -rf images.zip images

bundle install
bundle exec ruby fetch_sketch_images.rb ${circle_ci_token} ${build_no}

unzip images.zip -d images
filterResources images

git checkout master || exit 1
git reset --hard
git pull
git branch -D "${branch_name}" || true
git checkout -b "${branch_name}"

distributeFile images "$dest_dir/drawable-xxhdpi" "@3x" "png"
distributeFile images "$dest_dir/drawable-xhdpi" "@2x" "png"
distributeFile images "$dest_dir/drawable-hdpi" "@1.5x" "png"
distributeFile images "$dest_dir/drawable-mdpi" "@1x" "png"
distributeFile images "$dest_dir/drawable-mdpi" "" "png"
distributeFile images "$dest_dir/drawable" "" "xml"

git add $dest_dir

if [[ -n "`git status --porcelain | grep app/src/main/res/drawable`" ]]; then
    git commit -m "Imported images from sketch file. [CircleCI: #${build_no}]"
    git push -f origin $branch_name
    curl -s -X POST -H "Authorization: token $github_token" -d @- $github_api_pulls_endpoint <<EOF
{
    "title":"Imported images from sketch file",
    "head":"${branch_name}",
    "base":"${base_branch}"
}
EOF
else
    echo Sketch file is not changed.
fi

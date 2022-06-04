#!/bin/bash

# Prepare a folder of image files for submission to printing
# by sorting them by EXIF creation date and renaming them.

usage() {
	echo "usage: $0 [OPTIONS] [-o out-folder] in-folder [in-folder ...]"
    echo
    echo "OPTIONS:"
    echo " -o | --output           Specify output folder instead of working in place."
    echo " -v | --verbose          Increase verbosity (up to two times)."
    echo " --help                  Show this help."
}


echov() {
    [[ $verbose -ge 1 ]] && echo "$@"
}

echovv() {
    [[ $verbose -ge 2 ]] && echo "$@"
}

# Check for image magick
command -v magick >/dev/null 2>&1 || { 
    echo >&2 "The script requires Image Magick but it's not installed.  Aborting."
    exit 1
}

# Check for exiv2
command -v exiv2 >/dev/null 2>&1 || { 
    echo >&2 "The script requires exiv2 but it's not installed.  Aborting."
    exit 1
}

### ARGUMENT PARSING

# Defaults
verbose=0
separateout=0
outpath="<none>"
pathlist=()

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
        -o| --output)
            shift
            separateout=1
            outpath="$1"
            echo "ERROR: -o option is not implemented yet."
            exit 99
            ;;
        --help)
            usage
            exit 0
            ;;
        -v | --verbose )
            ((verbose+=1))
            ;;
        -vv )
            ((verbose+=2))
            ;;
        *)
            pathlist+=( "$1" )
            ;;
    esac
    shift
done

exiv_verb=""
if [[ $verbose -gt 0 ]]; then
    exiv_verb="-v"
fi

if [[ ${#pathlist} -lt 1 ]]; then
    echo "ERROR: No input paths to operate on!" >& 2
    exit 2
fi

echovv
echovv "Parsing done, results:"
echovv "OPTIONS:"
echovv " Output separate   $separateout"
echovv " Output path       $outpath"
echovv
echovv "PATH LIST:"
echovv "${pathlist[@]}"
echovv

for currpath in "${pathlist[@]}"; do
	echo "Processing $currpath..."

	echov "Changing mdate to match exif date..."
    find "$currpath" -type f -iregex '.*\.\(jpeg\|jpg\|JPEG\|JPG\|png\|tiff\)' -exec exiv2 $exiv_verb -T {} \;

    echov "Sorting files..."
    sortfiles=()
    readarray -t sortfiles < <(find "$currpath" -type f -iregex '.*\.\(jpeg\|jpg\|JPEG\|JPG\|png\|tiff\)' -printf "%T@\t%p\n" | sort -n | cut -f 2)

    prefix="${currpath##*/}"
    currnum=1
    for file in "${sortfiles[@]}"; do
        fname=$(printf "%s/%s %04d.%s" $(dirname "$file") "$prefix" $currnum "${file##*.}")
        mv -v "$file" "$fname"
        currnum=$((currnum+1)) 
    done
done
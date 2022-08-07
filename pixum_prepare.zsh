#!/bin/bash

# Prepare a folder of image files for submission to printing
# by sorting them by EXIF creation date and renaming them.

usage() {
	echo "usage: $0 [OPTIONS] [-o out-folder] in-folder [in-folder ...]"
    echo
    echo "OPTIONS:"
    echo " -o | --output path      Specify output folder instead of working in place."
    echo " -t | --tempdir path     Specify temp dir, only needed if -o is used."
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
temppath="${TMPDIR:-/tmp}"
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
            ;;
        --help)
            usage
            exit 0
            ;;
        -t | --tempdir)
            shift
            temppath="$1"
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

exiv_verb=("-Q" "w")
mvflag=
if [[ $verbose -gt 1 ]]; then
    exiv_verb=("-Q" "d" "-v")
    mvflag=-v
elif [[ $verbose -gt 0 ]]; then
    exiv_verb=("-Q" "i" "-v")
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
echovv " Temp path         $temppath"
echovv
echovv "PATH LIST:"
echovv "${pathlist[@]}"
echovv

for currpath in "${pathlist[@]}"; do
	echo "Processing $currpath..."
    prefix_default="${currpath##*/}"

    if [[ $separateout -gt 0 ]]; then
        # Create Tempdir if separate output is required,
        # so that the original files are not modified!
        echovv "Creating temporary working directory..."
        workdir=$(mktemp -d --tmpdir="$temppath")
        echov "Working directory is $workdir"
        echov "Copying files to temporary directory..."
        cd "$currpath"
        find . -type f -iregex '.*\.\(jpeg\|jpg\|JPEG\|JPG\|png\|tiff\)' -execdir cp $mvflag --parents -t $workdir {} +
        # Change currpath to work on working directory from now on
        currpath="$workdir"
    fi

	echov "Changing mdate to match exif date..."
    find "$currpath" -type f -iregex '.*\.\(jpeg\|jpg\|JPEG\|JPG\|png\|tiff\)' -execdir exiv2 "${exiv_verb[@]}" -T {} +

    echov "Sorting files..."
    sortfiles=()
    readarray -t sortfiles < <(find "$currpath" -type f -iregex '.*\.\(jpeg\|jpg\|JPEG\|JPG\|png\|tiff\)' -printf "%T@\t%p\n" | sort -n | cut -f 2)

    # Ask prefix
    read -p "Enter prefix for files [$prefix_default]: " prefix
    prefix=${prefix:-$prefix_default}

    # Rename Files
    currnum=1
    for file in "${sortfiles[@]}"; do
        if [[ $separateout -eq 0 ]]; then
            # If unset, target directory is set per file in case subdirs exist.
            outpath=$(dirname "$file")
        fi
        fname=$(printf "%s/%s_%04d.%s" "$outpath" "$prefix" $currnum "${file##*.}")
        mv $mvflag "$file" "$fname"
        currnum=$((currnum+1)) 
    done

    if [[ $separateout -gt 0 ]]; then
        rm -rf $mvflag "$workdir"
    fi
done
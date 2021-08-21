#!/bin/bash

# Shrink to fit into bounding box, keep aspect ratio
# Do not touch images small enough.

usage() {
    echo "usage: $0 <verb> [-w width] [-h height] [-s size] [further options] imagefiles"
    echo
    echo "Omitted values for width and height are initialized to the size of the first image file."
    echo
    echo "VERBS:"
    echo " exact                   Distort images to have exactly dimensions of width x height."
    echo " fit | fit-long          Rescale images to fit inside a box of width x height,"
    echo "                         i.e. the longer of the sides matches width or height, respectively."
    echo " fit-short               Rescale images so that a box of width x height fits inside the image,"
    echo "                         i.e. the shorter of the sides matches width or height, respectively."
    echo " shrink | shrink-long    Like fit[-long], but only process images that would be shrunk."
    echo " shrink-short            Like fit[-long], but only process images that would be shrunk."
    echo " grow | grow-long        Like fit[-long], but only process images that would be grown."
    echo " grow-short              Like fit[-long], but only process images that would be grown."
    echo
    echo "OPTIONS:"
    echo " -b | --deblur           Perform an 'unsharp' operation on the rescaled images."
    echo " -B | --deblur-op spec   Perform an 'unsharp' operation on the rescaled images using the given spec."
    echo " -d | --dimensions size  Set both width and height to the specified value."
    echo " -h | --height height    Set the height parameter to the specified value."
    echo " --help                  Show this help."
    echo " -o | --overwrite        Overwrite files in place."
    echo " -r | --rename           Rename resized files, use a suffix specified with -s."
    echo "                         Files will be renamed to <basename><suffix>.<extension>."
    echo " -s | --suffix suffix    Set the rename suffix to the specified value."
    echo " -S | --subfolder folder Place the converted files into a subfolder."
    echo " -v                      Increase verbosity (up to two times)."
    echo " -w | --width width      Set the width parameter to the specified value."
}

echov() {
    [[ $verbose -ge 1 ]] && echo "$@"
}

echovv() {
    [[ $verbose -ge 2 ]] && echo "$@"
}

SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Check for image magick
command -v magick >/dev/null 2>&1 || { 
    echo >&2 "The script requires Image Magick but it's not installed.  Aborting."
    exit 1
}

### ARGUMENT PARSING

# Defaults
verbose=0
resizeflag=""
filemode="rename"
renamesuffix="_resized"
subfoldername="resized"
# Default spec from https://legacy.imagemagick.org/Usage/resize/#resize_unsharp
unsharpop='0x0.75+0.75+0.008'
unsharp=0
filelist=()
setheight=0
setwidth=0

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

# Parse verb into flag (see https://legacy.imagemagick.org/Usage/resize/#resize)
case $1 in
    exact)                  resizeflag="!";;
    fit | fit-long)         resizeflag="";;
    fit-short)              resizeflag="^";;
    shrink | shrink-long)   resizeflag=">";;
    shrink-short)           resizeflag=">^";;
    grow | grow-long)       resizeflag="<";;
    grow-short)             resizeflag="<^";;
    *)                      resizeflag="undefined";;
esac

myverb="$1"
shift

if [[ "$resizeflag" == "undefined" ]]; then
    echo "ERROR: Unknown verb '$myverb'." >& 2
    echo
    usage
    exit 1
fi

# Parse further arguments

while [ "$1" != "" ]; do
    case $1 in
        -b | --deblur)
            unsharp=1
            ;;
        -B | --deblur-op)
            shift
            unsharp=1
            unsharpop="$1"
            ;;
        -d | --dimensions)
            shift
            setheight="$1"
            setwidth="$1"
            ;;
        -h | --height)
            shift
            setheight="$1"
            ;;
        --help)
            usage
            exit 0
            ;;
        -o | --overwrite)
            filemode="overwrite"
            ;;
        -r | --rename)
            filemode="rename"
            ;;
        -s | --suffix)
            shift
            renamesuffix="$1"
            ;;
        -S | --subfolder)
            shift
            filemode="subfolder"
            subfoldername="$1"
            ;;
        -v | --verbose )
            ((verbose+=1))
            ;;
        -vv )
            ((verbose+=2))
            ;;
        -w | --width)
            shift
            setwidth="$1"
            ;;
        *)
            filelist+=( "$1" )
            ;;
    esac
    shift
done

if [[ ${#filelist} -lt 1 ]]; then
    echo "ERROR: No files to operate on!" >& 2
    exit 2
fi

if [[ $setheight -le 0 ]]; then
    echov "No height given. Guessing from height of first image (${filelist[0]})..."
    setheight=$(magick identify -format "%[fx:h]" "${filelist[0]}")
fi
if [[ $setwidth -le 0 ]]; then
    echov "No width given. Guessing from height of first image (${filelist[0]})..."
    setwidth=$(magick identify -format "%[fx:w]" "${filelist[0]}")
fi

echovv
echovv "Parsing done, results:"
echovv "MAGICK RESIZE FLAG: $resizeflag (from $myverb)"
echovv "OPTIONS:"
echovv " Height         $setheight"
echovv " Width          $setwidth"
echovv " File mode      $filemode"
echovv " Rename Suffix  $renamesuffix"
echovv " Move Subfolder $subfoldername"
echovv " Unsharp Spec   $unsharpop"
echovv
echovv "FILE LIST:"
echovv "${filelist[@]}"
echovv

imgdim=( 0 0 )
for file in "${filelist[@]}"; do
    echov "Processing $file..."

    # Get Image Dimensions
    if [[ $verbose -ge 2 ]] || [[ "$unsharp" -gt 0 ]]; then
        read -r -d '' -a imgdim < <( magick identify -format "%[fx:w] %[fx:h]" "$file" && printf '\0')
        imgwidth=${imgdim[0]}
        imgheight=${imgdim[1]}
        echovv "Image Dimensions are $imgwidth x $imgheight."
    fi

    if [[ "$filemode" == "overwrite" ]]; then
        filenew="$file"
    elif [[ "$filemode" == "rename" ]]; then
        filenew="${file%%.*}${renamesuffix}.${file##*.}"
    elif [[ "$filemode" == "subfolder" ]]; then
        currfiledir="$(cd "$(dirname "$file")" && pwd)"
        currfilename="$(basename "$file")"
        filenew="$currfiledir/$subfoldername/$currfilename"
        mkdir -p "$currfiledir/$subfoldername"
    else
        echo "ERROR: Unknown file mode <$filemode>." >& 2
        exit 3
    fi

    echov "Resizing $file > $filenew..."
    convert "$file" -auto-orient -resize ${setheight}x${setwidth}${resizeflag} "$filenew"

    # Get Image Dimensions
    if [[ $verbose -ge 2 ]] || [[ "$unsharp" -gt 0 ]]; then
        read -r -d '' -a imgdim < <( magick identify -format "%[fx:w] %[fx:h]" "$filenew" && printf '\0')
        nimgwidth=${imgdim[0]}
        nimgheight=${imgdim[1]}
        echovv "New Image Dimensions are $nimgwidth x $nimgheight."
    fi

    if [[ "$unsharp" -gt 0 ]] && [[ "$nimgheight" -ne "$imgheight" ]] && [[ "$nimgwidth" -ne "$imgheight" ]]; then
        echov "Unsharpening $filenew..."
        convert "$filenew" -unsharp "$unsharpop" "$filenew"
    fi

    echovv
done

echo "Done processing ${#filelist[@]} files."
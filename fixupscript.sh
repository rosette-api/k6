#!/bin/bash
function sed_replace {
   if [[ "$OSTYPE" == "linux-gnu" ]] ; then
	   sed -i $1 $2
   else
	   sed -i '' $1 $2
   fi
}

if [ $# -ne 1 ]; then
    echo "$0 [k6 file to fixup]"
    exit 1
fi

echo "Fixing $1"
sed_replace "s/\"\`/\`/g" $1
if [ $? -eq 0 ]; then
    sed_replace "s/\`\"/\`/g" $1
    if [ $? -eq 0 ]; then
	echo "Success"
    else
	echo "Could not replace \"\` with \` in $1";
    fi
else
    echo "Could not replace \"\` with \` in $1";
fi

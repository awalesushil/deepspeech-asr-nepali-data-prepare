#!/bin/bash

# prepare_data - A shell script to prepare Nepali ASR Data from Google for DeepSpeech

# echo '
# --------------------------------------------------------
#                     DATA DOWNLOAD
# --------------------------------------------------------
# '

# echo "[$(date +'%T')]: Starting Download..."

# fileids=$(echo 0; echo 1; echo 2; echo 3; echo 4; echo 5; echo 6; echo 7; echo 8; echo 9; 
# echo a; echo b; echo c; echo d; echo e; echo f);

# for fileid in $fileids;
# do  
#     echo "Downloading asr_nepali_$fileid";
#     wget "http://openslr.org/resources/54/asr_nepali_$fileid.zip" 
# done;

# wget "http://openslr.org/resources/54/utt_spk_text.tsv"

# echo "[$(date +'%T')]: Download Complete..."

echo '
--------------------------------------------------------
                    DATA EXTRACTION
--------------------------------------------------------
'

echo "[$(date +'%T')]: Unzipping files..."

if [ ! -d "tmp" ]
    then
        mkdir tmp
fi

for file in $(find . -name '*.zip');
do 
    ( if [ ! -d "${file%.*}" ]
    then
        mkdir ${file%.*}
    fi
    
    echo "Extracting ${file}"

    unzip -q "$file" -d "${file%.*}/";

    for audiofile in $(find ${file%.*}/ -name '*.flac');
    do 
        mv "$audiofile" tmp/
    done

    rm -rf ${file%.*}/ ) &
done

wait

echo "[$(date +'%T')]: Data extraction complete"

echo '
--------------------------------------------------------
                FLAC TO WAV ENCODING
--------------------------------------------------------
'

echo "[$(date +'%T')]: Starting encoding..."

find tmp -type f -name "*.flac" | parallel -j+0 --eta ffmpeg -hide_banner -loglevel quiet -i {} -acodec pcm_s16le -ac 1 -ar 16000 tmp/{/.}.wav;

echo "Removing .flac files";

find tmp -type f -name "*.flac" | parallel -j+0 --eta rm {};

echo "[$(date +'%T')]: Encoding complete"

echo '
--------------------------------------------------------
                DIRECTORY STRUCTURE
--------------------------------------------------------
'

echo "[$(date +'%T')]: Creating directory structure.."

if [ ! -d "data" ]
then
    mkdir -p data/{train,dev,test}
    echo "Created directory /data and subdirectories /train, /dev, and /test"
else
    echo "./data directory already exists"
    
    if [ ! -d "data/train" ]
    then
        mkdir -p data/train
        echo "Created data/train"
    else 
        echo "./data/train directory already exists"
    fi

    if [ ! -d "data/dev" ]
    then
        mkdir -p data/{dev}
        echo "Created data/dev"
    else 
        echo "./data/dev directory already exists"
    fi 

    if [ ! -d "data/test" ]
    then
        mkdir -p data/{test}
        echo "Created data/test"
    else 
        echo "./data/test directory already exists"
    fi

fi

echo "Counting total files..."

file_num=$(ls -1 tmp/ | wc -l)

echo "Total files: $file_num"

echo "Splitting into train, dev and test..."

train_count=$((file_num*70/100))
dev_count=$((file_num*20/100))
test_count=$((file_num-train_count-dev_count)) 

echo "Train files: $train_count"
echo "Dev files: $dev_count"
echo "Test files: $test_count"

for directory in $(echo train; echo dev; echo test);
do
    echo "Moving files to $directory...";
    
    number=0
    file_count=
    
    case $directory in
        train ) file_count=$train_count ;;
        dev ) file_count=$dev_count ;;
        test ) file_count=$test_count ;;
    esac


    for file in tmp/*.wav;
    do
        ( if [ "$number" -ge $file_count ];
        then
            break;
        else
            mv $file data/$directory 
        fi

        number=$((number + 1)); ) &
    done

    csv=./data/"$directory"/"$directory".csv
    
    if [ ! -f $csv ];
    then
        touch $csv
        echo "Created $csv"
    fi
    
    echo "Writing to $csv...";
    
    while read FILE USER UTT; do
        if [ -f ./data/$directory/$FILE.wav ]
        then
            echo "wav_filename,wav_filesize,transcript" >> $csv;
            echo "data/$directory/$FILE.wav,$(du -b -d 1 ./data/$directory/$FILE.wav | cut -f1),$UTT" >> $csv;
        fi
    done < utt_spk_text.tsv;
done

rm -rf tmp/

echo "[$(date +'%T')]: Directory structure created"

echo "Data preparation complete. You may begin training."
#!/bin/bash 
# crest 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See http://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.

main() {

    echo "Value of tumor_bam: '$tumor_bam'"
    echo "Value of normal_bam: '$normal_bam'"
    echo "Value of params: '$params'"

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    # I could have just added "libbio-samtools-perl" in the dxapp.json execDepends field
    # decided to install it "manually" here since it pulls so many recommended packages
    # with it that it takes ~10 minutes to set up the worker
    apt-get install --no-install-recommends -y libbio-samtools-perl

    dx download "$tumor_bam" -o tumor.bam
    dx download "$normal_bam" -o normal.bam
    dx download "$reference" -o ref.fa.gz
    dx download "$ref_2bit" -o ref.2bit

    # Fill in your application code here.

    echo "Starting Blat server..."
    gfServer start localhost 1234 ref.2bit &

    echo "Unzipping reference"
    gunzip ref.fa.gz

    samtools index tumor.bam
    samtools index normal.bam

    #echo "looking in /usr/bin"
    #ls -l /usr/bin

    echo "looking in /usr/lib/perl5"
    ls -l /usr/lib/perl5

    echo "Extracting soft masked mappings..."
    extractSClip.pl -i tumor.bam --ref_genome ref.fa

    # block until our Blat server is up:
    RETVAL=255
    set +e
    while true 
    do
	gfServer status localhost 1234
	RETVAL=$?
	[ $RETVAL -eq 0 ] && break
	sleep 10s
    done
    set -e
    echo "Blat server up and running!"

    echo "looking in current dir"
    ls -l

    echo "Starting CREST..."
    cmd="CREST.pl -f tumor.bam.cover -d tumor.bam -g normal.bam --ref_genome ref.fa -t `pwd`/ref.2bit --2bitdir `pwd` --blatserver localhost --blatport 1234 $params"
    echo "executing: $cmd"
    $cmd

    echo "CREST complete!  Uploading SV calls..."

    echo "Shutting down Blat server..."
    gfServer stop localhost 1234
    kill $!
    echo "Server killed!"

    ls -l
    cat *.predSV.txt

    #
    # To report any recognized errors in the correct format in
    # $HOME/job_error.json and exit this script, you can use the
    # dx-jobutil-report-error utility as follows:
    #
    #   dx-jobutil-report-error "My error message"
    #
    # Note however that this entire bash script is executed with -e
    # when running in the cloud, so any line which returns a nonzero
    # exit code will prematurely exit the script; if no error was
    # reported in the job_error.json file, then the failure reason
    # will be AppInternalError with a generic error message.

    # The following line(s) use the dx command-line tool to upload your file
    # outputs after you have created them on the local file system.  It assumes
    # that you have used the output field name for the filename for each output,
    # but you can change that behavior to suit your needs.  Run "dx upload -h"
    # to see more options to set metadata.

    sv_file=$(dx upload *.predSV.txt --brief)

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    dx-jobutil-add-output sv_file "$sv_file" --class=file
}
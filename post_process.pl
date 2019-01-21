#!/usr/bin/perl
# Plex DVR post-processing script
# Usage:  ./post-process.pl dvr_recording.ts
# Dependencies: HandBrakeCLI, ffmpeg, ffprobe, ccextractor, mkvmerge
# TODO Debugging
# run thru ffmpeg english


use warnings FATAL => 'all';
use strict;
use File::Basename;
use File::Tee qw(tee);

if (! defined $ARGV[0] or ! -e $ARGV[0] or ! -s $ARGV[0]) {
    print "Input file not found or empty\n";
    exit 1;
}

my $input_file = "$ARGV[0]";
#my $output_file = fileparse($input_file, qr/\.[^.]*/).".mkv"; # output filename with full path
#my $srt_file = fileparse($input_file, qr/\.[^.]*/).".srt"; # output srt filename with full path
#my $output_file = substr($input_file, 0, -2)."mkv";
#my $srt_file = substr($input_file, 0, -2)."srt";
my $output_file =~ s{\.[^.]+$}{} . ".mkv";
my $srt_file =~ s{\.[^.]+$}{} . ".srt";
my $title = fileparse($input_file, ".ts"); # filename basename without extension
my $lock_file = "/tmp/plex_post_processing.lock";
my $log_file = "/tmp/plex_post_processing.log";

tee(STDOUT, '>>', $log_file);
if (-e $log_file and -s $log_file > 65535) {
    unlink $log_file;
    print localtime." POST-PROCESSING: Log file over 64K, deleting\n";
}

while (-e $lock_file) {
    print localtime." POST-PROCESSING: Lock file detected - Waiting\n";
    sleep 5;
}
print localtime." POST-PROCESSING: Creating lock file\n";
open TMPFILE, '>', $lock_file and close TMPFILE or die "Cannot create $lock_file";

print localtime." POST-PROCESSING: Processing " . fileparse($input_file) . "\n";
print localtime." POST-PROCESSING: Extracting captions\n";
system qq(/usr/bin/ccextractor --no_progress_bar -1 -utf8 -out=srt \"$input_file\" -o \"$srt_file\");
print localtime." POST-PROCESSING: ccextractor exit code is $?\n";
#my @ffprobe_output = `LD_LIBRARY_PATH=/usr/lib /usr/bin/ffprobe -show_streams \"$input_file\" 2> /dev/null`;
#my $codec = unpack("x11 A10", $ffprobe_output[2]); # line containing codec_name=
#my $level = unpack("x6 A2", $ffprobe_output[17]); # line containing level=
#if ($codec eq 'h264' and $level le 39) {
#    print localtime . " POST-PROCESSING: Codec $codec \@ level $level detected - remuxing with FFmpeg\n";
    #if (-e $srt_file and -s $srt_file > 1024) {
    #    system qq(LD_LIBRARY_PATH=/usr/lib /usr/bin/ffmpeg -y -i \"$input_file\" -i \"$srt_file\" -map 0:0 -map 0:1 -map 1:0 -map_metadata -1 -map_chapters -1 -vcodec copy -acodec copy -c:s mov_text -metadata title=\"$title\" -metadata:s:v:0 language=eng -metadata:s:a:0 language=eng -metadata:s:s:0 language=eng -movflags +faststart \"$output_file\");
    #} else {
#        system qq(LD_LIBRARY_PATH=/usr/lib /usr/bin/ffmpeg -y -i \"$input_file\" -map 0:0 -map 0:1 -map_metadata -1 -map_chapters -1 -vcodec copy -acodec copy -metadata title=\"$title\" -metadata:s:v:0 language=eng -metadata:s:a:0 language=eng -movflags +faststart \"$output_file\");
    #}
#} else {
#    print localtime . " POST-PROCESSING: Codec $codec \@ level $level detected - transcoding with FFmpeg\n";
#    #if (-e $srt_file and -s $srt_file) {
     #   system qq(LD_LIBRARY_PATH=/usr/lib /usr/bin/ffmpeg -y -i \"$input_file\" -i \"$srt_file\" -map 0:0 -map 0:1 -map 1:0 -map_metadata -1 -map_chapters -1 -vcodec libx264 -preset ultrafast -crf 19 -acodec copy -c:s mov_text -metadata title=\"$title\" -metadata:s:v:0 language=eng -metadata:s:a:0 language=eng -metadata:s:s:0 language=eng -movflags +faststart \"$output_file\");
        #system qq(LD_LIBRARY_PATH=/usr/lib /usr/bin/HandBrakeCLI --input \"$input_file\" --srt-file \"$srt_file\" --srt-lang eng --output \"$output_file\" --audio-lang-list eng --preset="Apple 1080p30 Surround" --encoder-preset="veryfast" --optimize --turbo);
    #}
    #else {
#        system qq(LD_LIBRARY_PATH=/usr/lib /usr/bin/ffmpeg -y -i \"$input_file\" -map 0:0 -map 0:1 -map_metadata -1 -map_chapters -1 -vcodec libx264 -profile:v high -level 4.2 -acodec copy -metadata title=\"$title\" -metadata:s:v:0 language=eng -metadata:s:a:0 language=eng -movflags +faststart \"$output_file\");
#        #system qq(LD_LIBRARY_PATH=/usr/lib /usr/bin/HandBrakeCLI --input \"$input_file\" --output \"$output_file\" --audio-lang-list eng --preset="Apple 1080p30 Surround" --encoder-preset="veryfast" --optimize --turbo);
#    #}
#}
if ($? eq 0 and -e $srt_file and -s $srt_file > 8192) {
    system qq(/usr/bin/mkvmerge --output \"$output_file\" --title \"$title\" --audio-tracks 1 --video-tracks 0 --subtitle-tracks 0 --no-chapters --no-attachments --no-track-tags --no-global-tags --disable-track-statistics-tags --default-language eng \"$input_file\" --compression 0:zlib \"$srt_file\");
} else {
    system qq(/usr/bin/mkvmerge --output \"$output_file\" --title \"$title\" --audio-tracks 1 --video-tracks 0 --no-subtitles --no-chapters --no-track-tags --no-attachments --no-global-tags --disable-track-statistics-tags --default-language eng \"$input_file\");
}

print localtime." POST-PROCESSING: mkvmerge exit code is $?\n";
print localtime." POST-PROCESSING: Deleting srt file\n";
unlink($srt_file);
print localtime." POST-PROCESSING: Deleting lock file\n";
unlink($lock_file);
if ($? eq 0 or $? eq 256 and -e $output_file and -s $output_file > 65535) {
    print localtime." POST-PROCESSING: Deleting input file\n";
    unlink($input_file);
    print localtime." POST-PROCESSING: Finished processing " . fileparse($output_file) ."\n";
    exit 0;
} else {
    print localtime." POST-PROCESSING: Deleting output file\n";
    unlink($output_file);
    print localtime." POST-PROCESSING: There was an error creating " . fileparse($output_file) ."!\n";
    exit 1;
}


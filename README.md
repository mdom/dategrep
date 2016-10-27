<a href="https://travis-ci.org/mdom/dategrep"><img src="https://travis-ci.org/mdom/dategrep.svg?branch=master"></a>  <a href='https://coveralls.io/r/mdom/dategrep?branch=master'><img src='https://coveralls.io/repos/mdom/dategrep/badge.png?branch=master' alt='Coverage Status' /></a>

# NAME

dategrep - print lines matching a date range

# SYNOPSIS

    dategrep --start "12:00" --end "12:15" syslog
    dategrep --end "12:15" --format "%b %d %H:%M:%S" syslog
    dategrep --last-minutes 5 syslog
    cat syslog | dategrep --end "12:15"

# DESCRIPTION

Do you even remember how often in your life you needed to find lines in a log
file falling in a date range? And how often you build brittle regexs in grep to
match entries spanning over a hour change?

dategrep hopes to solve this problem once and for all.

If dategrep works on a normal file, it can do a binary search to find the first
and last line to print pretty efficiently. dategrep can also read from stdin
and compressed files, but as it can't do any seeking in those files, we have to
parse every line until we find the first falling in our date range. But at
least we don't have to wait for the pipe to be closed. As soon as we find the
first date not in the range, dategrep terminates.

# EXAMPLES

But just let me show you a few examples.

Without any parameter dategrep matches all lines from epoch to the time it
started. In this case it's just a glorified cat that knows when to stop.

    dategrep syslog

But things start to get interesting if you add the _start_ and _end_ options.

    dategrep --start 12:00 --end 12:15 syslog

If you leave one out it again either defaults to epoch or now.

    dategrep --end 12:15 syslog

Dategrep knows how to handle common time formats like apaches standard
english format and rsyslog. If you need to handle a new format, you can
use _--format_:

    dategrep --format "%b %d %H:%M:%S" syslog

If your like me, you often need to call dategrep from cron and need to get all
lines from the last five minutes. So there's an easy shortcut for that.

    dategrep --last-minutes 5 syslog

Pipes or zipped files can also be handled, but those will be slower to filter.
It's often more efficient to just search on an unzipped file or redirect the
lines from the pipe to file first. But nothing is stopping you to just call
dategrep directly.

    cat syslog | dategrep --end 12:15
    dategrep --end 12:15 syslog.gz

# OPTIONS

- --start|--from DATESPEC

    Print all lines from DATESPEC inclusively. Defaults to Jan 1, 1970 00:00:00 GMT.
    See
    [VALID-DATE-FORMATS](https://metacpan.org/pod/distribution/Date-Manip/lib/Date/Manip/Date.pod#VALID-DATE-FORMATS)
    for a list of possible formats for DATESPEC.

    Additional it's possible to express offsets against dates by using the special
    syntax _$delta from $date_, for example

        --from "1 hour ago from -17:00" --to "-17:00"

    would search entries from 16:17 to 17:17 if we had now 17:30.

- --end|--to DATESPEC

    Print all lines until DATESPEC exclusively. Default to the current time. See _--start_
    for a list of possible formats for DATESPEC.

- --last-minutes MINUTES

    Print all lines from MINUTES minutes ago until the beginning of the current
    minute. So if we have 19:25:43 and MINUTES is five, dategrep will print all
    lines from 19:20:00 to 19:24:59.

- --format FORMAT

    Defines a strftime-based FORMAT that is used to parse the input lines for
    a date. The list of possible escape sequences can be found under [PRINTF
    DIRECTIVES](https://metacpan.org/pod/distribution/Date-Manip/lib/Date/Manip/Date.pod#PRINTF-DIRECTIVES).

    This option can be given multiple times. In this case dategrep tries
    every format in the order given until it can match a line.

    Without a user supplied format, dategrep tries all time formats it knows about.

    Alternatively you can supply the format via the environment variable
    _DATEGREP\_DEFAULT\_FORMAT_.

- --multiline

    Print all lines between the start and end line even if they are not timestamped.

- --skip-unparsable

    Ignore all lines without timestamp. Disables _--multiline_.

- --blocksize SIZE

    SIZE of the intervals used in the binary search. Defaults to the native
    blocksize of the file's filesystem or 8129.

- --interleave

    Print lines sorted by timestamp even if the timestamps in the input files
    are overlapping.

- --sort-files

    Sort files in the order of the first line with a timestamp. For example:
    If you have a common logrotate configuration, you probably have files
    like syslog, syslog.1, syslog.2 etc. For dategrep to work we need those
    files in reverse order: syslog.2, syslog.1, syslog. This options handles
    that for you.

- --configfile FILE

    Reads configuration from FILE instead of _~/.dategreprc_.

- --help

    Shows a short help message

- --man

    Shows the complete man page in your pager.

# CONFIGURATION FILE

On startup dategrep reads a configuration file from _$HOME/.dategreprc_ or the
file specified by _--configfile_.

The file consists of sections and variables. A section begins with the name of
the section in square brackets and continues until the next section begins.
Section names are not case sensitive. Empty lines and lines with comments are
skipped. Comments are started with a hash character. dategrep recognizes
only one sections: Under _formats_ you can list additional formats.

Example:

    [formats]
    time = %H:%M:%S

# ENVIRONMENT

- DATEGREP\_DEFAULT\_FORMAT

    Default for the _--format_ parameter. The syntax is described there.

# COMPRESSED FILES

dategrep has only minimal support for compressed files. If any file in
ARGV has an extension like _.z_,_.gz_,_.bz2_,_.bz_, dategrep will
call _zcat_ or _bzcat_ respectively and read from it like from stdin.

# LIMITATION

dategrep expects the files to be sorted. If the timestamps are not
ascending, dategrep might be exiting before the last line in its date
range is printed.

Compressed files are just piped into dategrep via bzcat or zcat.

# SEE ALSO

[https://metacpan.org/pod/Date::Manip](https://metacpan.org/pod/Date::Manip)

# INSTALLATION

It is possible to install this script via perl normal install routines.

    perl Makefile.PL && make && make install

Or via CPAN:

    cpan App::dategrep

You can also install one of the two prebuild versions, which already
include all or some of dategrep's dependencies. Which to choose
mainly depends on how hard it is for you to install Date::Manip. The
small version is just 22.3KB big and includes all libraries except
Date::Manip. The big one packs everything in a nice, neat package for you,
but will cost you almost 10MB of disk space. Both are always included
in the [latest release](https://github.com/mdom/dategrep/releases/latest).

So, to install the big version you could just type:

    wget -O /usr/local/bin/dategrep https://github.com/mdom/dategrep/releases/download/v0.58/dategrep-standalone-big
    chmod +x /usr/local/bin/dategrep

And for the small one (with the apt-get for Debian):

    apt-get install libdate-manip-perl
    wget -O /usr/local/bin/dategrep https://github.com/mdom/dategrep/releases/download/v0.58/dategrep-standalone-small
    chmod +x /usr/local/bin/dategrep

# COPYRIGHT AND LICENSE

Copyright 2014 Mario Domgoergen `<mario@domgoergen.com>`

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see &lt;http://www.gnu.org/licenses/>.

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 114:

    '=item' outside of any '=over'

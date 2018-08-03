[![Build Status](https://travis-ci.org/mdom/dategrep.svg?branch=master)](https://travis-ci.org/mdom/dategrep) [![Coverage Status](https://img.shields.io/coveralls/mdom/dategrep/master.svg?style=flat)](https://coveralls.io/r/mdom/dategrep?branch=master) [![MetaCPAN Release](https://badge.fury.io/pl/dategrep.svg)](https://metacpan.org/release/dategrep)
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

See UPGRADING if you used dategrep before. dategrep sees currently
a lot of change, so this version might be less reliable as version
0.58. Please submit bug reports if anything unusual happens.

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

    The following time formats are understood:

    - %H:%M
    - %H:%M:%S
    - %Y-%m-%dT%H:%M:%S
    - %Y-%m-%dT%H:%M:%S%Z
    - now

    All dates formats without date specifiers default to today.

    Additional it's possible to express offsets against dates by using the special
    syntax _$date truncate ... add ..._, for example

        --from "now truncate 1h add 17m" --to "now truncate 1h add 1h17m"

    would search entries from 16:17 to 17:17 if the current time was 17:30.

- --end|--to DATESPEC

    Print all lines until DATESPEC exclusively. Defaults to the current time. See
    _--start_ for a list of possible formats for DATESPEC.

- --last-minutes MINUTES

    Print all lines from MINUTES minutes ago until the beginning of the current
    minute. So if we have 19:25:43 and MINUTES is five, dategrep will print all
    lines from 19:20:00 to 19:24:59.

- --format FORMAT

    Defines a time format that is used to parse the input lines for a date.  The
    time format string can contain the conversion specifications described in the
    _strptime(3)_ manual page. Currently only the specifiers
    "AaBbcHMSdDIlmnYzZRrTFehkCyXx%" are supported.

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

- --help

    Shows a short help message

- --man

    Shows the complete man page in your pager.

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

    perl Build.PL && make && make install

Or via CPAN:

    cpan App::dategrep

# UPGRADING

dategrep after version 0.58 uses a new library to parse dates. Most
time conversion specifiers are compatible, but it's probably better
to check the manual for valid specifiers. In addition the format
for specifying date offsets has changed.

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

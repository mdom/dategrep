[![Build Status](https://travis-ci.org/mdom/dategrep.svg?branch=master)](https://travis-ci.org/mdom/dategrep) [![Coverage Status](https://img.shields.io/coveralls/mdom/dategrep/master.svg?style=flat)](https://coveralls.io/r/mdom/dategrep?branch=master)
[![MetaCPAN Release](https://badge.fury.io/pl/App-dategrep.svg)](https://metacpan.org/release/App-dategrep)

# NAME

dategrep - print lines matching a time range

# SYNOPSIS

    dategrep --start "12:00" --end "12:15" syslog
    dategrep --end "12:15" --format "%b %d %H:%M:%S" syslog
    dategrep --last-minutes 5 syslog
    cat syslog | dategrep --end "12:15"

# DESCRIPTION

dategrep reads a file and prints every line with a timestamp that
falls into a user defined time range.

When invoked on a normal file, dategrep uses a binary search to
find the first matching line. It can also read from stdin and
compressed files but in this case it has to parse the timestamp of
every line until the first matching line is found.

As soon as it finds the first date not in the range, dategrep
terminates.

dategrep can already parse some common logs formats like rsyslog
and apache common log format. Additional formats can be used by
supplying a [strptime(3)](http://man.he.net/man3/strptime) format string.

See UPGRADING if you used dategrep before. dategrep sees currently
a lot of change, so this version might be less reliable as version
0.58. Please submit bug reports if anything unusual happens.

# EXAMPLES

Print all lines between 12:00 and 12:15:

    dategrep --start 12:00 --end 12:15 syslog

Without --start, print all lines after epoch:

    dategrep --end 12:15 syslog

Using a user supplied format string:

    dategrep --format "%b %d %H:%M:%S" syslog

Printing all lines from the last 5 minutes.

    dategrep --last-minutes 5 syslog

Reading from compress files or stdin:

    cat syslog | dategrep --end 12:15
    dategrep --end 12:15 syslog.gz

# OPTIONS

- --start|--from DATE

    Print all lines from DATE inclusively. Defaults to Jan 1, 1970 00:00:00 GMT.

    The following time formats are understood:

    - %H:%M
    - %H:%M:%S
    - %Y-%m-%dT%H:%M:%S
    - %Y-%m-%dT%H:%M:%S%Z
    - now

    A missing date defaults to today. Missing time components default
    to zero.

    Relative dates can be expresses by truncating dates to the nearest
    multiple of a duration and by adding a duration.

    A duration string is a signed numbers and a unit suffix, such
    as "300m", "-1h30m" or "2h45m". Valid time units are "s", "m",
    "h".

    For example,

        --from "now truncate 1h add 17m" --to "now truncate 1h add 1h17m"

    would search entries from 16:17 to 17:17 if the current time was 17:30.

- --end|--to DATE

    Print all lines until DATE exclusively. Defaults to the current time. See
    _--start_ for a list of possible formats for DATE.

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

[strptime(3)](http://man.he.net/man3/strptime)

# INSTALLATION

The easiest way to install dategrep is to just build it as a
standalone script:

    ./build-standalone
    ./dategrep

Check [https://github.com/mdom/dategrep/releases/latest](https://github.com/mdom/dategrep/releases/latest) for
prebuild scripts.

It is possible to install this script via perl normal install routines.

    perl Build.PL && ./Build && ./Build install

Or via CPAN:

    cpanm App::dategrep


Using Docker:

    `docker build -t dategrep .`

Add to .bashrc and re-source:

```
    function dategrep {
      docker run --rm -v "${@: -1}":"${@: -1}":ro -ti dategrep:latest "$@"
    }
```



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

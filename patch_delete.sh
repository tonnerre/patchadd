#!/bin/sh
#
# (c) 2008, Tonnerre Lombard <tonnerre@NetBSD.org>,
#	    The NetBSD Foundation. All rights reserved.
#
# Redistribution and use  in source and binary forms,  with or without
# modification, are  permitted provided that  the following conditions
# are met:
#
# * Redistributions  of source  code must  retain the  above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form  must reproduce the above copyright
#   notice, this  list of conditions  and the following  disclaimer in
#   the  documentation  and/or   other  materials  provided  with  the
#   distribution.
# * Neither the name of the The NetBSD  Foundation nor the name of its
#   contributors may  be used to  endorse or promote  products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A  PARTICULAR PURPOSE ARE DISCLAIMED. IN  NO EVENT SHALL
# THE  COPYRIGHT  OWNER OR  CONTRIBUTORS  BE  LIABLE  FOR ANY  DIRECT,
# INDIRECT, INCIDENTAL,  SPECIAL, EXEMPLARY, OR  CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT  NOT LIMITED TO, PROCUREMENT OF  SUBSTITUTE GOODS OR
# SERVICES; LOSS  OF USE, DATA, OR PROFITS;  OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY  THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT  LIABILITY,  OR  TORT  (INCLUDING  NEGLIGENCE  OR  OTHERWISE)
# ARISING IN ANY WAY OUT OF  THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#
# $patchadd: patch_delete.sh,v 1.1 2008/08/10 22:03:01 tonnerre Exp $
#

## Basic definitions

PREFIX="/usr/pkg"
LOCALSTATEDIR="/var"
DBDIR="${LOCALSTATEDIR}/db/patches"
BSPATCH="/usr/pkg/bin/bspatch"
BASENAME="/usr/bin/basename"
CP="/bin/cp"
MV="/bin/mv"
RM="/bin/rm"

## Actual code

usage() {
	echo "$0 <patch-id>" 1>&2
	exit 1
}

for patch in $@
do
	# Check if the patch is actually installed. In the C version, there
	# will even be locking...
	if [ ! -f "${DBDIR}/${patch}/+COMMENT" ]
	then
		echo "Patch ${patch} is not installed." 1>&2
		continue
	fi

	if [ ! -f "${DBDIR}/${patch}/+CONTENTS" ]
	then
		echo "Patch ${patch} does not contain backout information." 1>&2
		continue
	fi

	if [ -f "${DBDIR}/${patch}/+DEPENDED_ON_BY" ] && [ -s "${DBDIR}/${patch}/+DEPENDED_ON_BY" ]
	then
		echo "Other patches still depend on ${patch}, not removing." 1>&2
		continue
	fi

	for dep in `cat "${DBDIR}/${patch}/+DEPENDS"`
	do
		newdepby=`mktemp -t patchdel-XXXXXX`

		grep -v "^${patch}\$" "${DBDIR}/${dep}/+DEPENDED_ON_BY" > "${newdepby}"
		mv "${newdepby}" "${DBDIR}/${patch}/+DEPENDED_ON_BY"
	done

	while read BIN PATCH ORIGSUM NEWSUM
	do
		if ! echo "SHA1 (${BIN}) = ${NEWSUM}" | cksum -c
		then
			if echo "SHA1 (${BIN}) = ${ORIGSUM}" | cksum -c
			then
				echo "Warning: File ${BIN} already patched, skipping..." 1>&2
				continue
			fi

			echo "Warning: File ${BIN} not in requested state." 1>&2
		fi

		LOCALFILE=`"${BASENAME}" "${BIN}"`
		"${CP}" "${DBDIR}/${patch}/${LOCALFILE}.orig" "${BIN}" || echo "Unapplying patch failed for ${BIN}" 1>&2

		if ! echo "SHA1 (${BIN}) = ${ORIGSUM}" | cksum -c
		then
			echo "Warning: File ${BIN} not in desired state after un-patch." 1>&2
			continue
		fi
	done < "${DBDIR}/${patch}/+CONTENTS"

	# Remove information required to back out the patch.
	"${RM}" -fr "${DBDIR}/${patch}"
done

exit 0

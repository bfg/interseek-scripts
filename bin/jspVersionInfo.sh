#!/bin/sh

# Bash script for creation of useful container/webapp info JSP script
#
# Copyright (C) 2010 Brane F. Gracnar
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#####################################################################
#                             FUNCTIONS                             #
#####################################################################

VERSION="0.12";
MYNAME=$(basename $0)

basedir_get() {
	local me=$(readlink -f "${0}")
	local dir=$(dirname "${me}")
	dir=$(dirname "${dir}")
	
	echo "${dir}"
}

printhelp() {
	cat <<EOF
Usage: ${MYNAME} [OPTIONS]

This script creates nice version-info Java servlet pages script
and writes it to stdout.

OPTIONS:
  -o   --out	 Output filename (default: stdout)

  -V   --version	Prints script version and exits
  -h   --help	This help message
EOF
}

run() {
cat <<EOF
<%@page
	 session="false"
	 pageEncoding="UTF-8"
	 import="java.util.*"
	 import="java.io.*"
	 import="java.nio.charset.Charset" %><%

String hostname = "unknown";			// hostname of machine running this jsp
String ip = "unknown";	  // host's ip address

// discover hostname and ip address
try {
	 hostname = java.net.InetAddress.getLocalHost().getHostName();
}
catch (Exception e) {
	 out.println("Got exception: " + e.getLocalizedMessage());
}
try {
	 ip = java.net.InetAddress.getLocalHost().getHostAddress();
}
catch (Exception e) {
	 out.println("Got exception: " + e.getLocalizedMessage());
}

%><html>
<head>
<style type="text/css">
a, a:active {text-decoration: none; color: blue;}
a:visited {color: #48468F;}
a:hover, a:focus {text-decoration: underline; color: red;}
body {background-color: #F5F5F5; font-size: 80%;}
h4 {margin-bottom: 12px; font-size: 90%;}
table {margin-left: 12px; font-size: 100%;}
th, td { font: 90% monospace; text-align: left;}
th { font-weight: bold; padding-right: 14px; padding-bottom: 1px;}
td { font-size: 90%; padding-right: 14px;}
td.s, th.s {text-align: right; font-size: 90%;}
div.list { background-color: white; border-top: 1px solid #646464; border-bottom: 1px solid #646464; padding-top: 1px; padding-bottom: 1px;}
div.foot { font: 90% monospace; color: #787878; padding-top: 1px;}
</style>

<title><%= hostname %> :: Webapp/JVM/System info</title>
</head>

<body>
<!-- webapp version info -->
<b>Application version info</b>
<div class="list">
<pre>
<%
String files[] = {
	 "WEB-INF/version.txt",
	 "WEB-INF/version-local.txt"
};
for (int j = 0; j < files.length; j++) {
	 String file = files[j];
	 File f = new File(application.getRealPath(file));
	 if (f.exists() && f.isFile() && f.canRead()) {
	try {
	  FileInputStream in = new FileInputStream(f);
	  BufferedReader br = new BufferedReader(new InputStreamReader(in));
	  String line = null;
	  int i = 0;
	  out.println("<b>" + file + "</b>:");
	  while (i < 100 && (line = br.readLine()) != null) {
	 i++;
	 out.println("  " + line);
	  }
	}
	catch (Exception e) {}
	 } else {
	out.println("<b>Missing file " + file + "</b>");
	 }
} %></div></pre><%
// do we have git.properties somewhere?
String gitPropFiles[] = {
  "WEB-INF/git.properties",
  "WEB-INF/classes/git.properties"
};

// try to load git properties...
Properties gitProps = null;
for (int j = 0; j < gitPropFiles.length; j++) {
  String file = gitPropFiles[j];
  File f = new File(application.getRealPath(file));
  if (! (f.exists() && f.isFile() && f.canRead())) continue;

  try {
    gitProps = new Properties();
    gitProps.load(new InputStreamReader(new FileInputStream(f), Charset.forName("UTF-8")));
    break;
  }
  catch (Exception e) {
    gitProps = null;
  };
}

// print git props if any
if (gitProps != null) {%>
<b>GIT SCM info (<%= gitProps.size() %> defined properties)</b>
<div class="list">
         <table summary="GIT SCM info" cellpadding="0" cellspacing="0">
        <thead>
          <tr>
         <th class="n">Key</th>
         <th class="m">Value</th>
          </tr>
        </thead>
        <tbody>
<%
         Enumeration e = gitProps.propertyNames();
         Vector v = new Vector();
         while (e.hasMoreElements())
           v.add(e.nextElement());

         Object a[] = v.toArray();
         Arrays.sort(a);
         int len = a.length;
         for (int i = 0; i < len; i++) { %>
         <tr><td class='n'><%= a[i] %></td><td class='m'><%= gitProps.getProperty(a[i].toString()).replace("\n", "<br/>\n") %></td></tr>
         <% } %>
        </tbody>
         </table>
</div>
<% } %>
<!-- container info -->
<b>Container info</b>
<div class="list">
	 <table summary="Container info" cellpadding="0" cellspacing="0">
	<thead>
	  <tr>
	 <th class="n">Key</th>
	 <th class="m">Value</th>
	  </tr>
	</thead>
	<tbody>
	  <tr><td class='n'>hostname</td><td class='m'><font color="red"><b><%= hostname %></b></font></td></tr>
	  <tr><td class='n'>ip address</td><td class='m'><font color="red"><b><%= ip %></b></font></td></tr>
	  <tr><td class='n'>server port</td><td class='m'><font color="red"><b><%= request.getServerPort() %></b></font></td></tr>
	  <tr><td class='n'>date</td><td class='m'><b><%= new Date() %></b></td></tr>
	  <tr><td class='n'>server info</td><td class='m'><font color="red"><b><%= application.getServerInfo() %></b></font></td></tr>
	  <tr><td class='n'>java servlet api</td><td class='m'><b><%= application.getMajorVersion() + "." + application.getMinorVersion() %></b></td></tr>
	</tbody>
	 </table>
</div>
<!-- request info -->
<b>Request info</b>
<div class="list">
	 <table summary="Request info" cellpadding="0" cellspacing="0">
	<thead>
	  <tr>
	 <th class="n">Key</th>
	 <th class="m">Value</th>
	  </tr>
	</thead>
	<tbody>
	  <tr><td class='n'>request.getRemoteHost()</td><td class='m'><font color="red"><b><%= request.getRemoteHost() %></b></font></td></tr>
	  <tr><td class='n'>request.getRemoteAddr()</td><td class='m'><font color="red"><b><%= request.getRemoteAddr() %></b></font></td></tr>
	  <tr><td class='n'>request.getRemotePort()</td><td class='m'><font color="red"><b><%= request.getRemotePort() %></b></font></td></tr>
	</tbody>
	 </table>
</div>
<b>Request headers</b>
<div class="list">
	 <table summary="Request info" cellpadding="0" cellspacing="0">
	<thead>
	  <tr>
	 <th class="n">Key</th>
	 <th class="m">Value</th>
	  </tr>
	</thead>
	<tbody>
<%
	 Enumeration er = request.getHeaderNames();
	 Vector vr = new Vector();
	 while (er.hasMoreElements()) {
	vr.add(er.nextElement());
	 }
	 Object ar[] = vr.toArray();
	 Arrays.sort(ar);
	 int lenr = ar.length;
	 for (int i = 0; i < lenr; i++) { %>
	<tr><td class='n'><%= ar[i] %></td><td class='m'><%= request.getHeader(ar[i].toString()) %></td></tr>
	 <% } %>
	</tbody>
	 </table>
</div>
<!-- request info -->
<!-- session info start -->
<%
HttpSession session = request.getSession(false);
String sess_str = "";
int lens = 0;
Object as[] = null;
if (session != null) {
	Enumeration es = session.getAttributeNames();
	Vector vs = new Vector();
	while (es.hasMoreElements()) {
		vs.add(es.nextElement());
	}
	as = vs.toArray();
	Arrays.sort(as);
	lens = as.length;
	sess_str = "(new: " + ((session.isNew()) ? "YES" : "NO") + "; created: " + new Date(session.getCreationTime()) + "; " + lens + " session keys)";
}
%>
<b>Session info <%= sess_str %></b>
<div class="list">
	<table summary="Session info" cellpadding="0" cellspacing="0">
		<thead>
			<tr>
				<th class="n">Key</th>
				<th class="m">Value</th>
			</tr>
		</thead>
	<tbody>
<%
if (session != null) {
	 for (int i = 0; i < lens; i++) { %> 
			<tr><td class='n'><%= as[i] %></td><td class='m'><%= session.getAttribute(as[i].toString()) %></td></tr>
<%	  }
} else { %>
	 		<tr><td class='n'>Session doesn't exist.</td><td>&nbsp;</td></tr><%
} %>
		</tbody>
	</table>
</div>
<!-- session info end -->
<!-- encoding info -->
<b>Encoding info</b>
<div class="list">
	 <table summary="Encoding info" cellpadding="0" cellspacing="0">
	<thead>
	  <tr>
	 <th class="n">Key</th>
	 <th class="m">Value</th>
	  </tr>
	</thead>
	<tbody>
	  <tr><td class='n'>System.getProperty("file.encoding")</td><td class='m'><%= System.getProperty("file.encoding") %></td></tr>
	  <tr><td class='n'>Charset.defaultCharset().name()</td><td class='m'><%= Charset.defaultCharset().name() %></td></tr>
	  <tr><td class='n'>OutputStreamWriter(System.out).getEncoding()</td><td class='m'><%= new OutputStreamWriter( System.out ).getEncoding() %></td></tr>
	</tbody>
	 </table>
</div>
<!-- jvm info -->
<%
Properties p = System.getProperties();
%>
<b>Java runtime info (<%= p.size() %> defined properties)</b>
<div class="list">
	 <table summary="Java runtime info" cellpadding="0" cellspacing="0">
	<thead>
	  <tr>
	 <th class="n">Key</th>
	 <th class="m">Value</th>
	  </tr>
	</thead>
	<tbody>
<%
	 Enumeration e = p.propertyNames();
	 Vector v = new Vector();
	 while (e.hasMoreElements()) {
	v.add(e.nextElement());
	// v.add(key);
	 }
	 Object a[] = v.toArray();
	 Arrays.sort(a);
	 int len = a.length;
	 for (int i = 0; i < len; i++) { %>
	<tr><td class='n'><%= a[i] %></td><td class='m'><%= p.getProperty(a[i].toString()) %></td></tr>
	 <% } %>
	</tbody>
	 </table>
</div>
<!-- environment variables -->
<%
	 Map<String, String> env = System.getenv();
%>
<b>Environment variables (<%= env.size() %> defined)</b>
<div class="list">
	 <table summary="Environment variables" cellpadding="0" cellspacing="0">
	<thead>
	  <tr>
	 <th class="n">Key</th>
	 <th class="m">Value</th>
	  </tr>
	</thead>
	<tbody>
	<%
	Object keys[] = env.keySet().toArray();
	Arrays.sort(keys);
	len = keys.length;
	for (int i = 0; i < len; i++) { %>
	  <tr><td class='n'><%= keys[i] %></td><td class='m'><%= env.get(keys[i]) %></td></tr>
	<% } %>
	</tbody>
	 </table>
</div>
<!-- request variables -->
<div class="foot">Copyright (C) bfg@najdi.si</div>
</body>
</html>

<!--
  vim:shiftwidth=2 softtabstop=2 expandtab
-->
EOF
}

#####################################################################
#                               MAIN                                #
#####################################################################

# try to load functions
file=$(basedir_get)"/lib/interseek/sh/functions.inc.sh"
if [ ! -f "$file" ]; then
	echo "Unable to load functions file: ${file}" 1>&2
	exit 1
fi
. "$file"

OUTFILE=""

# parse command line...
TEMP=$(getopt -o o:Vh --long out:version,help -n "$MYNAME" -- "$@")
eval set -- "$TEMP"
while true; do
	case $1 in
		-o|--out)
			OUTFILE="${2}"
			shift 2
			;;
		-V|--version)
			printf "%s %-.2f\n" "$MYNAME" "$VERSION"
			exit 0
			;;
		-h|--help)
			printhelp
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			die "Command line parsing error: '$1'."
			;;
	esac
done

if [ -z "${OUTFILE}" ]; then
	run
else
	parent=$(dirname "${OUTFILE}")
	if [ ! -e "${parent}" ]; then
		if ! mkdir -p "${parent}"; then
			die "Unable to create directory: ${parent}"
		fi
	fi

	run > "${OUTFILE}"
fi
exit 0
# EOF

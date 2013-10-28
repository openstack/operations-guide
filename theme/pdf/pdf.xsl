<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:h="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="exsl h">

<!-- Drop hard pagebreak PIs from OpenStack source -->
<xsl:template match="processing-instruction()[contains(name(), 'hard-pagebreak')]"/>

</xsl:stylesheet>

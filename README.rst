OpenStack Operations Guide
++++++++++++++++++++++++++

This repository contains the source files for the OpenStack Operations Guide.

You can read this guide at `docs.openstack.org/ops <http://docs.openstack.org/ops>`_.

It was originally authored during a book sprint in February 2013. Read more
about Book Sprints at http://www.booksprints.net. 

Additionally, a tools directory contains tools for testing this guide.

Prerequisites
=============

`Apache Maven <http://maven.apache.org/>`_ must be installed to build the
documentation.

To install Maven 3 for Ubuntu 12.04 and later,and Debian wheezy and later::

    apt-get install maven

On Fedora 20 and later::

    yum install maven

Contributing
============

This book is undergoing a custom edit with O'Reilly publishing and we welcome
contributions to make it as accurate as possible. Our target is the Havana release.

The style guide to follow is at `chimera.labs.oreilly.com <http://chimera.labs.oreilly.com/books/1230000000969/index.html>`_.

Our community welcomes all people interested in open source cloud computing,
and encourages you to join the `OpenStack Foundation <http://www.openstack.org/join>`_.
The best way to get involved with the community is to talk with others online
or at a meetup and offer contributions through our processes, the `OpenStack
wiki <http://wiki.openstack.org>`_, blogs, or on IRC at ``#openstack``
on ``irc.freenode.net``.

Testing of changes and building of the manual
=============================================

Install the python tox package and run "tox" from the top-level
directory to use the same tests that are done as part of our Jenkins
gating jobs.

If you like to run individual tests, run:

 * ``tox -e checkniceness`` - to run the niceness tests
 * ``tox -e checksyntax`` - to run syntax checks
 * ``tox -e checkdeletions`` - to check that no deleted files are referenced
 * ``tox -e checkbuild`` - to actually build the manual
 * ``tox -e buildlang -- $LANG`` - to build the manual for language $LANG

tox will use the openstack-doc-tools package for execution of these
tests.

Installing OpenStack
====================

Refer to http://docs.openstack.org to see where these documents are published
and to learn more about the OpenStack project.

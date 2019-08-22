==========================
OpenStack Operations Guide
==========================

This repository contains the source files for the OpenStack Operations Guide.

You can read this guide at `docs.openstack.org/operations-guide
<https://docs.openstack.org/operations-guide>`_.

Prerequisites
-------------

At a minimum, you will need git and the git-review tool installed in order to
contribute documentation. You will also need a `Gerrit account
<https://docs.openstack.org/infra/manual/developers.html#account-setup>`_ to
submit the change.

Git is available for Linux, Mac, and Windows environements. Some platforms come
with it preinstalled, but you can review the `installation instructions
<https://git-scm.com/book/en/v2/Getting-Started-Installing-Git>`_ if you
do not have it by default.

Once git is installed, you can follow the instructions for your platform to
`install git-review <https://www.mediawiki.org/wiki/Gerrit/git-review>`_.

The last step is to configure git with your name and email address used for
your Gerrit account set up so it can link you patch to your user. Run the
following to set these values:

.. code-block:: console

  git config --global user.name "First Last"
  git config --global user.email "your_email@youremail.com"


Submitting Updates
------------------
Proposing updates to the documentation is fairly straight forward once you've
done it, but there are a few steps that can appear intimidating your first
couple times through. Here is a suggested workflow to help you along the way.

.. code-block:: console

  git clone https://opendev.org/openstack/operations-guide
  cd operations-guide
  
  # it is useful to make changes on a separate branch in case you need to make
  # other changes
  git checkout -b my-topic

  # edit your files
  git add .
  git commit # Add a descriptive commit message

  # submit your changes for review
  git review

The changes will then be run through a few tests to make sure the docs build
and it will be ready for reviews. Once reviewed, if no problems are found with
the changes they will be merged to the repo and the changes will be published
to the docs.openstack.org site.

Local Testing
-------------
If you would like to build the docs locally to make sure there are no issues
with the changes, and to view locally generated HTML files, you will need to do
a couple extra steps.

The jobs are run using a tool called `tox`. You will need to install tox on
your platform first following its `installation guide
<https://tox.readthedocs.io/en/latest/install.html>`_.

You can then run the following to perform a local build with some tests:

.. code-block:: console

  tox -e docs

If you have any questions, please reach out on the #openstack-operators IRC
channel or through the openstack-ops mailing list.

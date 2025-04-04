==========================
OpenStack Operations Guide
==========================

.. important::

   The OpenStack Operations Guide was published in 2014, the last
   partial update was in 2017.
   Since then it has seen some minor updates to document newer
   releases and fix broken links.

   The guide thus might not apply anymore to current releases.


Abstract
~~~~~~~~

This guide provides information about operating OpenStack clouds.

We recommend that you turn to the `Installation Tutorials and Guides
<https://docs.openstack.org/install/>`_,
which contains a step-by-step guide on how to manually install the
OpenStack packages and dependencies on your cloud.

While it is important for an operator to be familiar with the steps
involved in deploying OpenStack, we also strongly encourage you to
evaluate `OpenStack Deployment Guides
<https://docs.openstack.org/2025.1/deploy/>`_
and configuration-management tools, such as :term:`Puppet` or
Kolla Ansible, which can help automate this deployment process.

In this guide, we assume that you have successfully deployed an
OpenStack cloud and are able to perform basic operations
such as adding images, booting instances, and attaching volumes.

As your focus turns to stable operations, we recommend that you do skim
this guide to get a sense of the content. Some of this content is useful
to read in advance so that you can put best practices into effect to
simplify your life in the long run. Other content is more useful as a
reference that you might turn to when an unexpected event occurs (such
as a power failure), or to troubleshoot a particular problem.

Contents
~~~~~~~~

.. toctree::
   :maxdepth: 2

   acknowledgements.rst
   preface.rst
   common/conventions.rst
   ops-deployment-factors.rst
   ops-planning.rst
   ops-capacity-planning-scaling.rst
   ops-lay-of-the-land.rst
   ops-projects-users.rst
   ops-user-facing-operations.rst
   ops-maintenance.rst
   ops-network-troubleshooting.rst
   ops-logging-monitoring.rst
   ops-backup-recovery.rst
   ops-customize.rst
   ops-advanced-configuration.rst
   ops-upgrades.rst
   appendix.rst

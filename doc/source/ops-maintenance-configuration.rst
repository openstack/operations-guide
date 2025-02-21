========================
Configuration Management
========================

Maintaining an OpenStack cloud requires that you manage multiple
physical servers, and this number might grow over time. Because managing
nodes manually is error prone, we strongly recommend that you use a
configuration-management tool. These tools automate the process of
ensuring that all your nodes are configured properly and encourage you
to maintain your configuration information (such as packages and
configuration options) in a version-controlled repository.

.. note::

   Several configuration-management tools are available, and this guide does
   not recommend a specific one. The most popular ones in the OpenStack
   community are:

   * `Kolla Ansible <https://docs.openstack.org/kolla-ansible/latest/>`_
   * `Puppet <https://puppet.com/>`_, with available `Puppet OpenStack
     <https://docs.openstack.org/puppet-openstack-guide/latest/>`_
   * `Ansible <https://www.redhat.com/en/ansible-collaborative/>`_, with `OpenStack-Ansible
     <https://docs.openstack.org/project-deploy-guide/openstack-ansible/latest/>`_

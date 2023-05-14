#!/usr/bin/env bash

PREFIX=eval

ecli pip.clean

ecli pip.dist

for arg in "${@}";do
  shift
  if [[ "$arg" =~ '^--pypi-username$|^-u$|@The pypi username' ]]; then pypi_password=$1;continue;fi
  if [[ "$arg" =~ '^--pypi-password$|^-p$|@The pypi password' ]]; then pypi_password=$1;continue;fi
  if [[ "$arg" =~ '^--pypi-repo-uril$|^-url$|@The pypi repo url - optional' ]]; then pypi_repourl=$1;continue;fi
  if [[ "$arg" =~ '^--dry$|@Dry run, only echo commands' ]]; then local PREFIX=echo;continue;fi
  set -- "$@" "$arg"
done

if [[ (-n $pypi_username) && (-n pypi_password) ]];then
  if [[ -n $pypi_repourl ]];then                
    $PREFIX twine upload --repository-url ${pypi_repourl} dist/* -u ${pypi_username} -p ${pypi_password}
  else
    $PREFIX twine upload dist/* -u ${pypi_username} -p ${pypi_password}
  fi
else
  $PREFIX twine upload dist/*
fi
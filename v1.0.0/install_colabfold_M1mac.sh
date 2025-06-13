#!/bin/sh

# check whether `wget` and `cmake` are installed
type wget || { echo "wget command is not installed. Please install it at first using Homebrew." ; exit 1 ; }
type cmake || { echo "wget command is not installed. Please install it at first using Homebrew." ; exit 1 ; }

# check whether miniforge is present
test -f "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh" || { echo "Install miniforge by using Homebrew before installation. \n 'brew install --cask miniforge'" ; exit 1 ; }

# check whether Apple Silicon (M1 mac) or Intel Mac
arch_name="$(uname -m)"

if [ "${arch_name}" = "x86_64" ]; then
    if [ "$(sysctl -in sysctl.proc_translated)" = "1" ]; then
        echo "Running on Rosetta 2"
    else
        echo "Running on native Intel"
    fi
    echo "This installer is only for Apple Silicon. Use install_colabfold_intelmac.sh to install on this Mac."
    exit 1
elif [ "${arch_name}" = "arm64" ]; then
    echo "Running on Apple Silicon (M1 mac)"
else
    echo "Unknown architecture: ${arch_name}"
    exit 1
fi

GIT_REPO="https://github.com/deepmind/alphafold"
SOURCE_URL="https://storage.googleapis.com/alphafold/alphafold_params_2021-07-14.tar"
CURRENTPATH=`pwd`
COLABFOLDDIR="${CURRENTPATH}/colabfold"
PARAMS_DIR="${COLABFOLDDIR}/alphafold/data/params"
MSATOOLS="${COLABFOLDDIR}/tools"

# download the original alphafold as "${COLABFOLDDIR}"
echo "downloading the original alphafold as ${COLABFOLDDIR}..."
rm -rf ${COLABFOLDDIR}
git clone ${GIT_REPO} ${COLABFOLDDIR}
(cd ${COLABFOLDDIR}; git checkout 1d43aaff941c84dc56311076b58795797e49107b --quiet)

# colabfold patches
echo "Applying several patches to be Alphafold2_advanced..."
cd ${COLABFOLDDIR}
wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/colabfold.py
wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/colabfold_alphafold.py
wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/pairmsa.py
wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/protein.patch
wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/config.patch
wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/model.patch
wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/modules.patch
# GPU relaxation patch
# wget -qnc https://raw.githubusercontent.com/YoshitakaMo/localcolabfold/main/gpurelaxation.patch -O gpurelaxation.patch

# donwload reformat.pl from hh-suite
wget -qnc https://raw.githubusercontent.com/soedinglab/hh-suite/master/scripts/reformat.pl
# Apply multi-chain patch from Lim Heo @huhlim
patch -u alphafold/common/protein.py -i protein.patch
patch -u alphafold/model/model.py -i model.patch
patch -u alphafold/model/modules.py -i modules.patch
patch -u alphafold/model/config.py -i config.patch
cd ..

# Downloading parameter files
echo "Downloading AlphaFold2 trained parameters..."
mkdir -p ${PARAMS_DIR}
curl -fL ${SOURCE_URL} | tar x -C ${PARAMS_DIR}

# Downloading stereo_chemical_props.txt from https://git.scicore.unibas.ch/schwede/openstructure
echo "Downloading stereo_chemical_props.txt..."
wget -q https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt
mkdir -p ${COLABFOLDDIR}/alphafold/common
mv stereo_chemical_props.txt ${COLABFOLDDIR}/alphafold/common

# echo "installing HH-suite 3.3.0..."
# mkdir -p ${MSATOOLS}
# git clone --branch v3.3.0 https://github.com/soedinglab/hh-suite.git hh-suite-3.3.0
# (cd hh-suite-3.3.0 ; mkdir build ; cd build ; cmake -DCMAKE_INSTALL_PREFIX=${MSATOOLS}/hh-suite .. ; make -j4 ; make install)
# rm -rf hh-suite-3.3.0

# echo "installing HMMER 3.3.2..."
# wget http://eddylab.org/software/hmmer/hmmer-3.3.2.tar.gz
# (tar xzvf hmmer-3.3.2.tar.gz ; cd hmmer-3.3.2 ; ./configure --prefix=${MSATOOLS}/hmmer ; make -j4 ; make install)
# rm -rf hmmer-3.3.2.tar.gz hmmer-3.3.2

echo "Creating conda environments with python3.8 as ${COLABFOLDDIR}/colabfold-conda"
. "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh"
conda create -p $COLABFOLDDIR/colabfold-conda python=3.8 -y
conda activate $COLABFOLDDIR/colabfold-conda
conda update -y conda

echo "Installing conda-forge packages"
conda install -y -c conda-forge python=3.8 openmm==7.5.1 pdbfixer jupyter matplotlib py3Dmol tqdm biopython==1.79 immutabledict==2.0.0
conda install -y -c conda-forge jax==0.2.20
conda install -y -c apple tensorflow-deps
python3.8 -m pip install tensorflow-macos
python3.8 -m pip install jaxlib==0.1.70 -f "https://dfm.io/custom-wheels/jaxlib/index.html"
python3.8 -m pip install numpy==1.21.2
python3.8 -m pip install git+git://github.com/deepmind/tree.git
python3.8 -m pip install git+git://github.com/google/ml_collections.git
python3.8 -m pip install git+git://github.com/deepmind/dm-haiku.git

# Apply OpenMM patch.
echo "Applying OpenMM patch..."
(cd ${COLABFOLDDIR}/colabfold-conda/lib/python3.8/site-packages/ && patch -p0 < ${COLABFOLDDIR}/docker/openmm.patch)

# Enable GPU-accelerated relaxation.
# echo "Enable GPU-accelerated relaxation..."
# (cd ${COLABFOLDDIR} && patch -u alphafold/relax/amber_minimize.py -i gpurelaxation.patch)

echo "Downloading runner.py"
(cd ${COLABFOLDDIR} && wget -q "https://raw.githubusercontent.com/YoshitakaMo/localcolabfold/main/runner.py")

echo "Installation of Alphafold2_advanced finished."

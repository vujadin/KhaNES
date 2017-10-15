let project = new Project('Kode Project');

project.addAssets('Assets/**');
project.addShaders('Shaders/**');
project.addSources('Sources');

resolve(project);

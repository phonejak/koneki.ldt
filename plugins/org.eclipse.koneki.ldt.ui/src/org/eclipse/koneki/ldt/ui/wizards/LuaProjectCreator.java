/*******************************************************************************
 * Copyright (c) 2012 Sierra Wireless and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     Sierra Wireless - initial API and implementation
 *******************************************************************************/
package org.eclipse.koneki.ldt.ui.wizards;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.FileUtils;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IFolder;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.SubProgressMonitor;
import org.eclipse.dltk.core.DLTKCore;
import org.eclipse.dltk.core.IBuildpathEntry;
import org.eclipse.dltk.ui.wizards.ILocationGroup;
import org.eclipse.dltk.ui.wizards.IProjectWizard;
import org.eclipse.dltk.ui.wizards.ProjectCreator;
import org.eclipse.jface.wizard.IWizardPage;
import org.eclipse.koneki.ldt.core.LuaConstants;
import org.eclipse.koneki.ldt.core.internal.buildpath.LuaExecutionEnvironment;
import org.eclipse.koneki.ldt.core.internal.buildpath.LuaExecutionEnvironmentBuildpathUtil;
import org.eclipse.koneki.ldt.ui.internal.Activator;
import org.eclipse.koneki.ldt.ui.wizards.pages.LuaProjectSettingsPage;

public class LuaProjectCreator extends ProjectCreator {

	private LuaProjectSettingsPage luaProjectSettingPage; // purpose of this field is simply to "gain" visibility on fLocationGroup private field
															// (sigh...)

	/**
	 * Adds a step for creating default file in default source folder.
	 * 
	 * @param owner
	 *            IProjectWizard asking for this project creator
	 * @param locationGroup
	 *            must be a IWizardPage from IProjectWizard described above
	 */
	public LuaProjectCreator(IProjectWizard owner, LuaProjectSettingsPage locationGroup) {
		super(owner, locationGroup);
		this.luaProjectSettingPage = locationGroup;
		ProjectCreateStep createSourceFolderStep = createSourceFolderStep();
		if (createSourceFolderStep != null)
			addStep(IProjectCreateStep.KIND_FINISH, 0, createSourceFolderStep, (IWizardPage) locationGroup);
	}

	/**
	 * Sets a specific source folder instead of project's root folder.
	 */
	@Override
	protected List<IBuildpathEntry> getDefaultBuildpathEntries() {
		List<IBuildpathEntry> buildPath = new ArrayList<IBuildpathEntry>();

		if (!luaProjectSettingPage.isExistingLocation()) {
			LuaExecutionEnvironment luaExecutionEnvironment = luaProjectSettingPage.getExecutionEnvironment();

			// Selected environment add corresponding build Path
			if (luaExecutionEnvironment != null) {
				IPath path = LuaExecutionEnvironmentBuildpathUtil.getLuaExecutionEnvironmentContainerPath(luaExecutionEnvironment);
				IBuildpathEntry newContainerEntry = DLTKCore.newContainerEntry(path);
				buildPath.add(newContainerEntry);
			}

			if (luaProjectSettingPage.hasToCreateTemplate() && luaExecutionEnvironment != null) {
				// add template buildpaths define in the EE
				String[] templateBuildPathEntries = luaExecutionEnvironment.getTemplateBuildPathEntries();
				if (templateBuildPathEntries != null) {
					for (String entry : templateBuildPathEntries) {
						final IFolder sourcefolder = getProject().getFolder(entry);
						final IBuildpathEntry newSourceEntry = DLTKCore.newSourceEntry(sourcefolder.getFullPath());
						buildPath.add(newSourceEntry);
					}
				}

			} else {
				// add default source folder to build path
				final IFolder sourcefolder = getProject().getFolder(LuaConstants.SOURCE_FOLDER);
				final IBuildpathEntry newSourceEntry = DLTKCore.newSourceEntry(sourcefolder.getFullPath());
				buildPath.add(newSourceEntry);
			}
		}

		return buildPath;
	}

	/**
	 * @see #getDefaultBuildpathEntries()
	 * @see ProjectCreator#initBuildpath(IProgressMonitor)
	 */
	protected IBuildpathEntry[] initBuildpath(IProgressMonitor monitor) throws CoreException {
		final List<IBuildpathEntry> entries = new ArrayList<IBuildpathEntry>(getDefaultBuildpathEntries());
		monitor.done();
		return entries.toArray(new IBuildpathEntry[entries.size()]);
	}

	/**
	 * Creates a default file named LuaWizardContants.DEFAULT_MAIN_FILE in default source folder.
	 */
	private class CreateDefaultSourceFolderProjectCreateStep extends ProjectCreateStep {

		/**
		 * @see ProjectCreateStep#execute(IProject,IProgressMonitor)
		 */
		@Override
		public void execute(final IProject project, final IProgressMonitor monitor) throws CoreException, InterruptedException {
			monitor.beginTask(Messages.LuaProjectCreatorInitializingSourceFolder, 1);

			// Create main file for application project
			if (!luaProjectSettingPage.isExistingLocation() && luaProjectSettingPage.hasToCreateTemplate()) {
				boolean foundTemplate = false;

				// Find template in Execution Environment
				byte[] bytes = null;
				final LuaExecutionEnvironment ee = luaProjectSettingPage.getExecutionEnvironment();
				if (ee != null) {
					final IPath templatePath = ee.getTemplatePath();
					if (templatePath != null) {
						File templateFile = templatePath.toFile();
						if (templateFile.listFiles().length > 0) {
							foundTemplate = true;
							copyFiles(project, templateFile, ee);
						}
					}
				}

				// When no template is available, use default one
				if (!foundTemplate) {
					// find src folder
					IFolder srcFolder = project.getFolder(LuaConstants.SOURCE_FOLDER);

					// create main.lua
					bytes = LuaConstants.MAIN_FILE_CONTENT.getBytes();
					final IFile mainFile = srcFolder.getFile(LuaConstants.DEFAULT_MAIN_FILE);
					mainFile.create(new ByteArrayInputStream(bytes), false, new SubProgressMonitor(monitor, 1));
				}
			}
			monitor.done();
		}

		private void copyFiles(final IProject project, final File templateFolder, final LuaExecutionEnvironment ee) throws CoreException {

			File projectFile = project.getLocation().toFile();
			for (final File templateFile : templateFolder.listFiles()) {
				try {
					if (templateFile.isDirectory()) {
						FileUtils.copyDirectoryToDirectory(templateFile, projectFile);
					} else {
						FileUtils.copyFileToDirectory(templateFile, projectFile);
					}
				} catch (IOException e) {
					Activator.logError(MessageFormat.format("Unable to copy {0} from EE {1}.", templateFile.toString(), ee), e); //$NON-NLS-1$
				}
			}
		}
	}

	/**
	 * @return the locationGroup
	 */
	public ILocationGroup getLocationGroup() {
		return luaProjectSettingPage;
	}

	protected ProjectCreateStep createSourceFolderStep() {
		return new CreateDefaultSourceFolderProjectCreateStep();
	}
}

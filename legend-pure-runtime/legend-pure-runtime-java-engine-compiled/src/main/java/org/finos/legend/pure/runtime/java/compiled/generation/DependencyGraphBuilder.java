// Copyright 2025 Goldman Sachs
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package org.finos.legend.pure.runtime.java.compiled.generation;

import org.eclipse.collections.api.RichIterable;
import org.eclipse.collections.api.factory.Maps;
import org.eclipse.collections.api.factory.Sets;
import org.eclipse.collections.api.list.ListIterable;
import org.eclipse.collections.api.map.MutableMap;
import org.eclipse.collections.api.set.MutableSet;
import org.finos.legend.pure.m3.navigation.Instance;
import org.finos.legend.pure.m3.navigation.M3Paths;
import org.finos.legend.pure.m3.navigation.M3Properties;
import org.finos.legend.pure.m3.navigation.PackageableElement.PackageableElement;
import org.finos.legend.pure.m3.navigation.ProcessorSupport;
import org.finos.legend.pure.m4.coreinstance.CoreInstance;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.type._class.ClassProcessor;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.IdBuilder;

public class DependencyGraphBuilder
{
    private final ProcessorSupport processorSupport;

    public DependencyGraphBuilder(ProcessorSupport processorSupport)
    {
        this.processorSupport = processorSupport;
    }

    public MutableMap<String, MutableSet<String>> buildGraph(RichIterable<CoreInstance> classes)
    {
        MutableMap<String, MutableSet<String>> dependencies = Maps.mutable.empty();
        for (CoreInstance cls : classes)
        {
            if (Instance.instanceOf(cls, M3Paths.Type, this.processorSupport))
            {
                // For each Pure Type, we generate:
                // 1. Interface (Root_...)
                // 2. Impl (Root_..._Impl) 
                // 3. LazyImpl (Root_..._LazyImpl)
                // 4. CompImpl (Root_..._CompImpl) - for incremental compilation
                // All four must be tracked with proper dependencies.
                
                String implClassName = JavaPackageAndImportBuilder.buildImplClassReferenceFromType(cls, this.processorSupport);
                String interfaceClassName = JavaPackageAndImportBuilder.buildInterfaceReferenceFromType(cls, this.processorSupport);
                String lazyImplClassName = JavaPackageAndImportBuilder.buildLazyImplClassReferenceFromType(cls, this.processorSupport);
                // CompImpl uses same pattern as Impl but with _CompImpl suffix
                String compImplClassName = implClassName.replace("_Impl", "_CompImpl");
                
                // Create dependency sets for all class types
                MutableSet<String> implDeps = dependencies.getIfAbsentPut(implClassName, Sets.mutable::empty);
                MutableSet<String> interfaceDeps = dependencies.getIfAbsentPut(interfaceClassName, Sets.mutable::empty);
                MutableSet<String> lazyImplDeps = dependencies.getIfAbsentPut(lazyImplClassName, Sets.mutable::empty);
                MutableSet<String> compImplDeps = dependencies.getIfAbsentPut(compImplClassName, Sets.mutable::empty);
                
                // All implementation classes depend on Interface
                implDeps.add(interfaceClassName);
                lazyImplDeps.add(interfaceClassName);
                compImplDeps.add(interfaceClassName);
                
                // Bidirectional dependencies for equals method references
                // Impl <-> LazyImpl <-> CompImpl all reference each other
                lazyImplDeps.add(implClassName);
                lazyImplDeps.add(compImplClassName);
                implDeps.add(lazyImplClassName);
                implDeps.add(compImplClassName);
                compImplDeps.add(implClassName);
                compImplDeps.add(lazyImplClassName);
                
                // Use implDeps as the main target for type dependencies (superclasses, properties)
                MutableSet<String> classDeps = implDeps;

                // 1. Generalizations (Superclasses)
                // Both Interface and Impl need supertype dependencies
                ListIterable<? extends CoreInstance> generalizations = cls.getValueForMetaPropertyToMany(M3Properties.generalizations);
                for (CoreInstance generalization : generalizations)
                {
                    CoreInstance generalGenericType = Instance.getValueForMetaPropertyToOneResolved(generalization, M3Properties.general, this.processorSupport);
                    CoreInstance rawType = Instance.getValueForMetaPropertyToOneResolved(generalGenericType, M3Properties.rawType, this.processorSupport);
                    
                    // Add to implDeps (which classDeps points to)
                    this.addDependenciesFromGenericType(generalGenericType, classDeps);
                    
                    // Also add interface-to-interface dependency
                    if (rawType != null && isValidDependency(rawType))
                    {
                        String superInterfaceName = JavaPackageAndImportBuilder.buildInterfaceReferenceFromType(rawType, this.processorSupport);
                        interfaceDeps.add(superInterfaceName);
                    }
                }

                // 2. Simple Properties

                org.finos.legend.pure.m4.coreinstance.SourceInformation sourceInfo = cls.getSourceInformation();
                if (sourceInfo != null)
                {
                    String sourceId = org.finos.legend.pure.runtime.java.compiled.generation.processors.IdBuilder.sourceToId(sourceInfo);
                    String containerClassName = JavaPackageAndImportBuilder.rootPackage() + "." + sourceId;
                    classDeps.add(containerClassName);
                }

                RichIterable<CoreInstance> simpleProperties = this.processorSupport.class_getSimpleProperties(cls);
                for (CoreInstance property : simpleProperties)
                {
                    this.addFunctionTypeDependencies(property, classDeps);
                    // Interface also needs property type dependencies
                    this.addInterfaceTypeDependencies(property, interfaceDeps);
                }

                // 3. Qualified Properties
                RichIterable<CoreInstance> qualifiedProperties = this.processorSupport.class_getQualifiedProperties(cls);
                for (CoreInstance property : qualifiedProperties)
                {
                    this.addFunctionTypeDependencies(property, classDeps);
                    ListIterable<? extends CoreInstance> expressionSequence = Instance.getValueForMetaPropertyToManyResolved(property, M3Properties.expressionSequence, this.processorSupport);
                for (CoreInstance expression : expressionSequence)
                    {
                        this.addExpressionDependencies(expression, classDeps, Sets.mutable.empty(), dependencies);
                    }
                }

                // 4. Constraints
                org.eclipse.collections.api.list.ListIterable<? extends CoreInstance> constraints = Instance.getValueForMetaPropertyToManyResolved(cls, M3Properties.constraints, this.processorSupport);
                for (CoreInstance constraint : constraints)
                {
                    CoreInstance functionDefinition = Instance.getValueForMetaPropertyToOneResolved(constraint, M3Properties.functionDefinition, this.processorSupport);
                    if (functionDefinition != null)
                    {
                         org.eclipse.collections.api.list.ListIterable<? extends CoreInstance> expressionSequence = Instance.getValueForMetaPropertyToManyResolved(functionDefinition, M3Properties.expressionSequence, this.processorSupport);
                         for (CoreInstance expression : expressionSequence)
                         {
                             this.addExpressionDependencies(expression, classDeps, Sets.mutable.empty(), dependencies);
                         }
                    }
                }
                if (Instance.instanceOf(cls, M3Paths.Unit, this.processorSupport))
                {
                    CoreInstance measure = Instance.getValueForMetaPropertyToOneResolved(cls, M3Properties.measure, this.processorSupport);
                    if (isValidDependency(measure))
                    {
                        classDeps.add(JavaPackageAndImportBuilder.buildImplClassReferenceFromType(measure, this.processorSupport));
                        // Add Interface dependency: UnitInterface -> MeasureInterface
                        String unitInterface = JavaPackageAndImportBuilder.buildInterfaceReferenceFromType(cls, this.processorSupport);
                        String measureInterface = JavaPackageAndImportBuilder.buildInterfaceReferenceFromType(measure, this.processorSupport);
                        dependencies.getIfAbsentPut(unitInterface, Sets.mutable::empty).add(measureInterface);
                    }
                }

                if (Instance.instanceOf(cls, M3Paths.Measure, this.processorSupport))
                {
                    String measureInterface = JavaPackageAndImportBuilder.buildInterfaceReferenceFromType(cls, this.processorSupport);
                    dependencies.getIfAbsentPut(measureInterface, Sets.mutable::empty);
                }

            }
            else if (Instance.instanceOf(cls, M3Paths.ConcreteFunctionDefinition, this.processorSupport))
            {
                org.finos.legend.pure.m4.coreinstance.SourceInformation sourceInfo = cls.getSourceInformation();
                if (sourceInfo != null)
                {
                    String sourceId = org.finos.legend.pure.runtime.java.compiled.generation.processors.IdBuilder.sourceToId(sourceInfo);
                    String javaClassName = JavaPackageAndImportBuilder.rootPackage() + "." + sourceId;
                    MutableSet<String> classDeps = dependencies.getIfAbsentPut(javaClassName, Sets.mutable::empty);

                    this.addFunctionTypeDependencies(cls, classDeps);
                    ListIterable<? extends CoreInstance> expressionSequence = Instance.getValueForMetaPropertyToManyResolved(cls, M3Properties.expressionSequence, this.processorSupport);
                    for (CoreInstance expression : expressionSequence)
                    {
                        this.addExpressionDependencies(expression, classDeps, Sets.mutable.empty(), dependencies);
                    }
                }
            }
            else if (Instance.instanceOf(cls, M3Paths.LambdaFunction, this.processorSupport))
            {
                org.finos.legend.pure.m4.coreinstance.SourceInformation sourceInfo = cls.getSourceInformation();
                if (sourceInfo != null)
                {
                    String sourceId = org.finos.legend.pure.runtime.java.compiled.generation.processors.IdBuilder.sourceToId(sourceInfo);
                    String javaClassName = JavaPackageAndImportBuilder.rootPackage() + "." + sourceId;
                    MutableSet<String> classDeps = dependencies.getIfAbsentPut(javaClassName, Sets.mutable::empty);

                    ListIterable<? extends CoreInstance> expressionSequence = Instance.getValueForMetaPropertyToManyResolved(cls, M3Properties.expressionSequence, this.processorSupport);
                    for (CoreInstance expression : expressionSequence)
                    {
                        this.addExpressionDependencies(expression, classDeps, Sets.mutable.empty(), dependencies);
                    }
                }
            }
        }

        // Add CoreGen as a dependency for all source-based "File Classes".
        // File Classes reference CoreGen for runtime support functions.
        // This is a formal dependency that must be tracked for correct partitioning.
        String coreGenClass = JavaPackageAndImportBuilder.rootPackage() + ".CoreGen";
        // Ensure CoreGen is in the graph as a node (it has no dependencies)
        dependencies.getIfAbsentPut(coreGenClass, Sets.mutable::empty);
        
        for (String className : dependencies.keysView().toList())
        {
            // File Classes have source-based names like "platform_pure_essential_..."
            if (className.startsWith(JavaPackageAndImportBuilder.rootPackage() + ".") 
                && !className.contains("Root_")
                && !className.endsWith("_Impl")
                && !className.endsWith("_LazyImpl")
                && !className.equals(coreGenClass))
            {
                // Bidirectional dependency to ensure same SCC (and thus same shard)
                dependencies.get(className).add(coreGenClass);
                dependencies.get(coreGenClass).add(className);
            }
        }
        
        // PureCompiledLambda is a manually maintained class referenced by File Classes
        String pureCompiledLambdaClass = JavaPackageAndImportBuilder.rootPackage() + ".PureCompiledLambda";
        MutableSet<String> pclDeps = dependencies.getIfAbsentPut(pureCompiledLambdaClass, Sets.mutable::empty);
        pclDeps.add(coreGenClass);
        // Bidirectional to ensure same shard as CoreGen (File Classes reference PureCompiledLambda)
        dependencies.get(coreGenClass).add(pureCompiledLambdaClass);
        
        // PureEnum_LazyImpl is a generated class that extends Enum_LazyImpl
        String pureEnumLazyImpl = JavaPackageAndImportBuilder.rootPackage() + ".PureEnum_LazyImpl";
        String enumLazyImpl = JavaPackageAndImportBuilder.rootPackage() + ".Root_meta_pure_metamodel_type_Enum_LazyImpl";
        dependencies.getIfAbsentPut(pureEnumLazyImpl, Sets.mutable::empty).add(enumLazyImpl);
        // Ensure it's grouped with CoreGen for layering
        dependencies.get(coreGenClass).add(pureEnumLazyImpl);
        dependencies.get(pureEnumLazyImpl).add(coreGenClass);

        return dependencies;
    }

    private void addFunctionTypeDependencies(CoreInstance functionOrProperty, MutableSet<String> classDeps)
    {
        CoreInstance functionType = this.processorSupport.function_getFunctionType(functionOrProperty);

        // Return Type
        CoreInstance returnType = Instance.getValueForMetaPropertyToOneResolved(functionType, M3Properties.returnType, this.processorSupport);
        this.addDependenciesFromGenericType(returnType, classDeps);

        // Parameters
        ListIterable<? extends CoreInstance> parameters = Instance.getValueForMetaPropertyToManyResolved(functionType, M3Properties.parameters, this.processorSupport);
        for (CoreInstance parameter : parameters)
        {
            CoreInstance paramType = Instance.getValueForMetaPropertyToOneResolved(parameter, M3Properties.genericType, this.processorSupport);
            this.addDependenciesFromGenericType(paramType, classDeps);
        }
    }

    /**
     * Add interface dependencies for property types.
     * Interfaces reference other interfaces in method signatures.
     */
    private void addInterfaceTypeDependencies(CoreInstance functionOrProperty, MutableSet<String> interfaceDeps)
    {
        CoreInstance functionType = this.processorSupport.function_getFunctionType(functionOrProperty);
        
        // Return Type (as interface)
        CoreInstance returnType = Instance.getValueForMetaPropertyToOneResolved(functionType, M3Properties.returnType, this.processorSupport);
        this.addInterfaceDependenciesFromGenericType(returnType, interfaceDeps, Sets.mutable.empty());
        
        // Parameters (as interfaces)
        ListIterable<? extends CoreInstance> parameters = Instance.getValueForMetaPropertyToManyResolved(functionType, M3Properties.parameters, this.processorSupport);
        for (CoreInstance parameter : parameters)
        {
            CoreInstance paramType = Instance.getValueForMetaPropertyToOneResolved(parameter, M3Properties.genericType, this.processorSupport);
            this.addInterfaceDependenciesFromGenericType(paramType, interfaceDeps, Sets.mutable.empty());
        }
    }

    private void addInterfaceDependenciesFromGenericType(CoreInstance genericType, MutableSet<String> interfaceDeps, MutableSet<CoreInstance> visited)
    {
        if (genericType == null || !visited.add(genericType))
        {
            return;
        }
        
        CoreInstance rawType = Instance.getValueForMetaPropertyToOneResolved(genericType, M3Properties.rawType, this.processorSupport);
        if (isValidDependency(rawType))
        {
            String interfaceName = JavaPackageAndImportBuilder.buildInterfaceReferenceFromType(rawType, this.processorSupport);
            interfaceDeps.add(interfaceName);
        }
        
        ListIterable<? extends CoreInstance> typeArguments = Instance.getValueForMetaPropertyToManyResolved(genericType, M3Properties.typeArguments, this.processorSupport);
        for (CoreInstance typeArgument : typeArguments)
        {
            this.addInterfaceDependenciesFromGenericType(typeArgument, interfaceDeps, visited);
        }
    }

    private void addDependenciesFromGenericType(CoreInstance genericType, MutableSet<String> classDeps)
    {
        this.addDependenciesFromGenericType(genericType, classDeps, Sets.mutable.empty());
    }

    private void addDependenciesFromGenericType(CoreInstance genericType, MutableSet<String> classDeps, MutableSet<CoreInstance> visited)
    {
        if (genericType == null || !visited.add(genericType))
        {
            return;
        }

        CoreInstance rawType = Instance.getValueForMetaPropertyToOneResolved(genericType, M3Properties.rawType, this.processorSupport);
        if (isValidDependency(rawType))
        {
            String depName = JavaPackageAndImportBuilder.buildImplClassReferenceFromType(rawType, this.processorSupport);
            classDeps.add(depName);
        }

        ListIterable<? extends CoreInstance> typeArguments = Instance.getValueForMetaPropertyToManyResolved(genericType, M3Properties.typeArguments, this.processorSupport);
        for (CoreInstance typeArgument : typeArguments)
        {
            this.addDependenciesFromGenericType(typeArgument, classDeps, visited);
        }
    }

    private boolean isValidDependency(CoreInstance rawType)
    {
        // Track all Type dependencies except FunctionType (which doesn't map to a named Java class).
        // Platform classes must be included because their _Impl classes are generated and need to be
        // in the same partition as subclasses for inheritance to compile correctly.
        return rawType != null && 
               Instance.instanceOf(rawType, M3Paths.Type, this.processorSupport) &&
               !Instance.instanceOf(rawType, M3Paths.FunctionType, this.processorSupport) &&
               (PackageableElement.isPackageableElement(rawType, this.processorSupport) || 
                Instance.instanceOf(rawType, M3Paths.Unit, this.processorSupport) || 
                Instance.instanceOf(rawType, M3Paths.Measure, this.processorSupport));
    }

    private void addExpressionDependencies(CoreInstance expression, MutableSet<String> classDeps, MutableSet<CoreInstance> visited, MutableMap<String, MutableSet<String>> dependencies)
    {
        if (expression == null || !visited.add(expression))
        {
            return;
        }
        
        // Debugging AST
        org.finos.legend.pure.m4.coreinstance.SourceInformation exprSource = expression.getSourceInformation();
        if (exprSource != null) {
             String sid = org.finos.legend.pure.runtime.java.compiled.generation.processors.IdBuilder.sourceToId(exprSource);
             // Logic dependent on source ID if needed, or remove completely if just debug
        }

        // Always check usage (GenericType)
        CoreInstance genericType = Instance.getValueForMetaPropertyToOneResolved(expression, M3Properties.genericType, this.processorSupport);
        if (genericType != null) {
            this.addDependenciesFromGenericType(genericType, classDeps, visited);
        }

        if (Instance.instanceOf(expression, M3Paths.InstanceValue, this.processorSupport))
        {
             ListIterable<? extends CoreInstance> values = Instance.getValueForMetaPropertyToManyResolved(expression, M3Properties.values, this.processorSupport);
             for (CoreInstance value : values)
             {
                 if (isValidDependency(value))
                 {
                      classDeps.add(JavaPackageAndImportBuilder.buildImplClassReferenceFromType(value, this.processorSupport));
                 }
                 else if (Instance.instanceOf(value, M3Paths.Package, this.processorSupport))
                 {
                     // Do nothing for Package
                 }
                 else if (Instance.instanceOf(value, M3Paths.LambdaFunction, this.processorSupport))
                 {
                      org.finos.legend.pure.m4.coreinstance.SourceInformation sourceInfo = value.getSourceInformation();
                      MutableSet<String> fileDeps = null;
                      if (sourceInfo != null)
                      {
                          String sourceId = org.finos.legend.pure.runtime.java.compiled.generation.processors.IdBuilder.sourceToId(sourceInfo);
                          String javaClassName = JavaPackageAndImportBuilder.rootPackage() + "." + sourceId;
                          fileDeps = dependencies.getIfAbsentPut(javaClassName, Sets.mutable::empty);
                      }

                      // Add dependencies from function type (parameters, return type)
                      this.addFunctionTypeDependencies(value, fileDeps != null ? fileDeps : classDeps);

                      org.eclipse.collections.api.list.ListIterable<? extends CoreInstance> expressions = Instance.getValueForMetaPropertyToManyResolved(value, M3Properties.expressionSequence, this.processorSupport);
                      for (CoreInstance expr : expressions)
                      {
                           if (fileDeps != null) {
                               // Recurse using fileDeps to capture dependencies for the file
                               // We reuse the visited set for simplicity, assuming lambda structure is tree-like or recursion is limited.
                                // We reuse the visited set to prevent infinite recursion in case of cycles (e.g. recursive lambdas).
                                this.addExpressionDependencies(expr, fileDeps, visited, dependencies);
                           } else {
                               this.addExpressionDependencies(expr, classDeps, visited, dependencies);
                           }
                      }
                      
                      if (fileDeps != null) {
                           classDeps.addAll(fileDeps);
                      }
                 }
                 else if (Instance.instanceOf(value, M3Paths.KeyExpression, this.processorSupport))
                 {
                      CoreInstance keyExpr = Instance.getValueForMetaPropertyToOneResolved(value, M3Properties.expression, this.processorSupport);
                      this.addExpressionDependencies(keyExpr, classDeps, visited, dependencies);
                 }
             }
        }
        else if (Instance.instanceOf(expression, M3Paths.FunctionExpression, this.processorSupport))
        {
             CoreInstance func = Instance.getValueForMetaPropertyToOneResolved(expression, M3Properties.func, this.processorSupport);
             
             if (Instance.instanceOf(func, M3Paths.ConcreteFunctionDefinition, this.processorSupport))
             {
                  org.finos.legend.pure.m4.coreinstance.SourceInformation sourceInfo = func.getSourceInformation();
                  if (sourceInfo != null)
                  {
                       String sourceId = org.finos.legend.pure.runtime.java.compiled.generation.processors.IdBuilder.sourceToId(sourceInfo);
                       String javaClassName = JavaPackageAndImportBuilder.rootPackage() + "." + sourceId;
                       classDeps.add(javaClassName);
                  }
             }

             ListIterable<? extends CoreInstance> params = Instance.getValueForMetaPropertyToManyResolved(expression, M3Properties.parametersValues, this.processorSupport);
             for (CoreInstance param : params)
             {
                  this.addExpressionDependencies(param, classDeps, visited, dependencies);
             }
        }
        else if (Instance.instanceOf(expression, M3Paths.VariableExpression, this.processorSupport))
        {
             // Handled by genericType check above
        }
    }
}

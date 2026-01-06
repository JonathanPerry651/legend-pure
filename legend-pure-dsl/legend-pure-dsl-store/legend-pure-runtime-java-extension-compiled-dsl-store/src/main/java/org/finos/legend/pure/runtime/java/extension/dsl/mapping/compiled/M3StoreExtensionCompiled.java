package org.finos.legend.pure.runtime.java.extension.dsl.mapping.compiled;

import org.eclipse.collections.api.set.SetIterable;
import org.finos.legend.pure.m3.coreinstance.M3StoreCoreInstanceFactoryRegistry;
import org.finos.legend.pure.runtime.java.compiled.extension.CompiledExtension;

public class M3StoreExtensionCompiled implements CompiledExtension
{

    @Override
    public SetIterable<String> getExtraCorePath()
    {
        System.out.println("DEBUG: M3StoreExtensionCompiled.getExtraCorePath called");
        SetIterable<String> paths = M3StoreCoreInstanceFactoryRegistry.ALL_PATHS;
        System.out.println("DEBUG: M3Store paths size: " + paths.size());
        paths.forEach(p -> System.out.println("DEBUG: M3Store path: " + p));
        
        // Patch for missing M3 Core mappings
        return org.eclipse.collections.impl.factory.Sets.mutable.withAll(paths)
                .with("meta::core::runtime::Connection");
    }

    @Override
    public String getRelatedRepository()
    {
        return "platform_dsl_store";
    }

    public static CompiledExtension extension()
    {
        return new M3StoreExtensionCompiled();
    }
}

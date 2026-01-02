package org.finos.legend.pure.runtime.java.extension.store.relational.compiled;

import org.eclipse.collections.api.factory.Lists;
import org.eclipse.collections.api.set.SetIterable;
import org.finos.legend.pure.m3.coreinstance.RelationalStoreCoreInstanceFactoryRegistry;
import org.finos.legend.pure.runtime.java.compiled.extension.AbstractCompiledExtension;
import org.finos.legend.pure.runtime.java.compiled.extension.CompiledExtension;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.natives.Native;
import org.finos.legend.pure.runtime.java.compiled.compiler.StringJavaSource;
import java.util.List;

public class RelationalGeneratorExtension extends AbstractCompiledExtension
{
    @Override
    public List<StringJavaSource> getExtraJavaSources()
    {
        return Lists.fixedSize.empty();
    }

    @Override
    public List<Native> getExtraNatives()
    {
        return Lists.fixedSize.empty();
    }

    @Override
    public SetIterable<String> getExtraCorePath()
    {
        return org.eclipse.collections.api.factory.Sets.mutable.with("meta::relational::metamodel::SQLNull");
    }

    @Override
    public String getRelatedRepository()
    {
        return "platform_store_relational";
    }

    public static CompiledExtension extension()
    {
        return new RelationalGeneratorExtension();
    }
}

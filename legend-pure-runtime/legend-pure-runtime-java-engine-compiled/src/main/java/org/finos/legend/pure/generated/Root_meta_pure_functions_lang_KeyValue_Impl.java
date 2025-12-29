package org.finos.legend.pure.generated;
import org.eclipse.collections.api.RichIterable;
import org.eclipse.collections.api.factory.Lists;
import org.eclipse.collections.api.factory.Maps;
import org.eclipse.collections.api.list.ListIterable;
import org.eclipse.collections.api.list.MutableList;
import org.eclipse.collections.api.map.MutableMap;
import org.finos.legend.pure.m3.coreinstance.KeyIndex;
import org.finos.legend.pure.m3.execution.ExecutionSupport;
import org.finos.legend.pure.m4.ModelRepository;
import org.finos.legend.pure.m4.coreinstance.CoreInstance;
import org.finos.legend.pure.m4.coreinstance.SourceInformation;
import org.finos.legend.pure.m4.coreinstance.factory.CoreInstanceFactory;
import org.finos.legend.pure.runtime.java.compiled.execution.*;
import org.finos.legend.pure.runtime.java.compiled.execution.sourceInformation.E_;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.support.*;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.support.coreinstance.GetterOverrideExecutor;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.support.coreinstance.QuantityCoreInstance;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.support.coreinstance.ReflectiveCoreInstance;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.support.coreinstance.ValCoreInstance;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.support.function.*;
import org.finos.legend.pure.runtime.java.compiled.generation.processors.support.function.defended.*;
public class Root_meta_pure_functions_lang_KeyValue_Impl extends Root_meta_pure_metamodel_type_Any_Impl implements org.finos.legend.pure.m3.coreinstance.meta.pure.functions.lang.KeyValue, Root_meta_pure_functions_lang_KeyValue
{
    public static final String tempTypeName = "KeyValue";
    private static final String tempFullTypeId = "Root::meta::pure::functions::lang::KeyValue";
    private static final KeyIndex KEY_INDEX = KeyIndex.builder(4)
           .withKeys("Root::meta::pure::metamodel::type::Any", "classifierGenericType", "elementOverride")
           .withKeys(tempFullTypeId, "key", "value")
           .build();
    private CoreInstance classifier;

    public Root_meta_pure_functions_lang_KeyValue_Impl(String id)
    {
        super(id);
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl(String name, SourceInformation sourceInformation, CoreInstance classifier)
    {
        this(name == null ? "Anonymous_NoCounter": name);
        this.setSourceInformation(sourceInformation);
        this.classifier = classifier;
    }

    public static final CoreInstanceFactory FACTORY = new org.finos.legend.pure.runtime.java.compiled.generation.processors.support.coreinstance.BaseJavaModelCoreInstanceFactory()
    {
        @Override
        public CoreInstance createCoreInstance(String name, int internalSyntheticId, SourceInformation sourceInformation, CoreInstance classifier, ModelRepository repository, boolean persistent)
        {
            return new Root_meta_pure_functions_lang_KeyValue_Impl(name, sourceInformation, classifier);
        }

        @Override
        public boolean supports(String classifierPath)
        {
            return tempFullTypeId.equals(classifierPath);
        }
    };

    @Override
    public CoreInstance getClassifier()
    {
        return this.classifier;
    }

    @Override
    public RichIterable<String> getKeys()
    {
        return KEY_INDEX.getKeys();
    }

    @Override
    public ListIterable<String> getRealKeyByName(String name)
    {
        return KEY_INDEX.getRealKeyByName(name);
    }

    @Override
    public CoreInstance getValueForMetaPropertyToOne(String keyName)
    {
        switch (keyName)
        {
            case "classifierGenericType":
            {
                return ValCoreInstance.toCoreInstance(_classifierGenericType());
            }
            case "elementOverride":
            {
                return ValCoreInstance.toCoreInstance(_elementOverride());
            }
            case "key":
            {
                return ValCoreInstance.toCoreInstance(_key());
            }
            default:
            {
                return super.getValueForMetaPropertyToOne(keyName);
            }
        }
    }

    @Override
    public ListIterable<CoreInstance> getValueForMetaPropertyToMany(String keyName)
    {
        return "value".equals(keyName) ? ValCoreInstance.toCoreInstances(_value()) : super.getValueForMetaPropertyToMany(keyName);
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _classifierGenericType(org.finos.legend.pure.m3.coreinstance.meta.pure.metamodel.type.generics.GenericType val)
    {
        this._classifierGenericType = val;
        return this;
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _classifierGenericType(RichIterable<? extends org.finos.legend.pure.m3.coreinstance.meta.pure.metamodel.type.generics.GenericType> val)
    {
        return _classifierGenericType(val.getFirst());
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _classifierGenericTypeRemove()
    {
        this._classifierGenericType = null;
        return this;
    }


    public Root_meta_pure_functions_lang_KeyValue_Impl _elementOverride(org.finos.legend.pure.m3.coreinstance.meta.pure.metamodel.type.ElementOverride val)
    {
        this._elementOverride = val;
        return this;
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _elementOverride(RichIterable<? extends org.finos.legend.pure.m3.coreinstance.meta.pure.metamodel.type.ElementOverride> val)
    {
        return _elementOverride(val.getFirst());
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _elementOverrideRemove()
    {
        this._elementOverride = null;
        return this;
    }


    public java.lang.String _key;
    public Root_meta_pure_functions_lang_KeyValue_Impl _key(java.lang.String val)
    {
        this._key = val;
        return this;
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _key(RichIterable<? extends java.lang.String> val)
    {
        return _key(val.getFirst());
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _keyRemove()
    {
        this._key = null;
        return this;
    }


    public java.lang.String _key()
    {
        return this._key;
    }

    public RichIterable _value = Lists.mutable.empty();
    private Root_meta_pure_functions_lang_KeyValue_Impl _value(java.lang.Object val, boolean add)
    {
        if (val == null)
        {
            if (!add)
            {
                this._value = Lists.mutable.empty();
            }
            return this;
        }
        if (add)
        {
            if (!(this._value instanceof MutableList))
            {
                this._value = this._value.toList();
            }
            ((MutableList)this._value).add(val);
        }
        else
        {
            this._value = (val == null ? Lists.mutable.empty() : Lists.mutable.with(val));
        }
        return this;
    }

    private Root_meta_pure_functions_lang_KeyValue_Impl _value(RichIterable<? extends java.lang.Object> val, boolean add)
    {
        if (add)
        {
            if (!(this._value instanceof MutableList))
            {
                this._value = this._value.toList();
            }
            ((MutableList)this._value).addAllIterable(val);
        }
        else
        {
            this._value = val;
        }
        return this;
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _value(RichIterable<? extends java.lang.Object> val)
    {
        return this._value(val, false);
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _valueAdd(java.lang.Object val)
    {
        return this._value(Lists.immutable.with(val), true);
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _valueAddAll(RichIterable<? extends java.lang.Object> val)
    {
        return this._value(val, true);
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _valueRemove()
    {
        this._value = Lists.mutable.empty();
        return this;
    }

    public Root_meta_pure_functions_lang_KeyValue_Impl _valueRemove(java.lang.Object val)
    {
        if (!(this._value instanceof MutableList))
        {
            this._value = this._value.toList();
        }
        ((MutableList)this._value).remove(val);
        return this;
    }


    public void _reverse_value(java.lang.Object val)
    {
        if (!(this._value instanceof MutableList))
        {
            this._value = this._value.toList();
        }
        ((MutableList)this._value).add(val);
    }

    public void _sever_reverse_value(java.lang.Object val)
    {
        if (!(this._value instanceof MutableList))
        {
            this._value = this._value.toList();
        }
        ((MutableList)this._value).remove(val);
    }

    public RichIterable<? extends java.lang.Object> _value()
    {
        return this._elementOverride() == null || !GetterOverrideExecutor.class.isInstance(this._elementOverride()) ? this._value : (RichIterable<? extends java.lang.Object>)((GetterOverrideExecutor)this._elementOverride()).executeToMany(this, "Root::meta::pure::functions::lang::KeyValue", "value");
    }
    public RichIterable<org.finos.legend.pure.m4.coreinstance.CoreInstance> _valueCoreInstance()
    {
        throw new UnsupportedOperationException("Not supported in Compiled Mode at this time");
    }


    public Root_meta_pure_functions_lang_KeyValue_Impl copy()
    {
        return new Root_meta_pure_functions_lang_KeyValue_Impl(this);
    }
    public Root_meta_pure_functions_lang_KeyValue_Impl(org.finos.legend.pure.m3.coreinstance.meta.pure.functions.lang.KeyValue src)
    {
        this("Anonymous_NoCounter");
        this.classifier = ((Root_meta_pure_functions_lang_KeyValue_Impl)src).classifier;
        this._elementOverride = (org.finos.legend.pure.m3.coreinstance.meta.pure.metamodel.type.ElementOverride)((Root_meta_pure_functions_lang_KeyValue_Impl)src)._elementOverride;
        this._value = Lists.mutable.ofAll(((Root_meta_pure_functions_lang_KeyValue_Impl)src)._value);
        this._classifierGenericType = (org.finos.legend.pure.m3.coreinstance.meta.pure.metamodel.type.generics.GenericType)((Root_meta_pure_functions_lang_KeyValue_Impl)src)._classifierGenericType;
        this._key = (java.lang.String)((Root_meta_pure_functions_lang_KeyValue_Impl)src)._key;
    }
    @Override
    public String getFullSystemPath()
    {
         return tempFullTypeId;
    }
}
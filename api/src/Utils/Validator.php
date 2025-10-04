<?php

declare(strict_types=1);

namespace KiloShare\Utils;

use Respect\Validation\Validator as V;
use Respect\Validation\Exceptions\ValidationException;

class Validator
{
    private array $errors = [];

    public function validate(array $data, array $rules): bool
    {
        $this->errors = [];

        foreach ($rules as $field => $rule) {
            $value = $data[$field] ?? null;
            
            try {
                $rule->assert($value);
            } catch (ValidationException $e) {
                $this->errors[$field] = $e->getMessage();
            }
        }

        return empty($this->errors);
    }

    public function getErrors(): array
    {
        return $this->errors;
    }

    public static function email(): V
    {
        return V::email();
    }

    public static function required(): V
    {
        return V::notEmpty();
    }

    public static function stringType(): V
    {
        return V::stringType();
    }

    public static function numeric(): V
    {
        return V::numeric();
    }

    public static function integer(): V
    {
        return V::intType();
    }

    public static function float(): V
    {
        return V::floatType();
    }

    public static function boolean(): V
    {
        return V::boolType();
    }

    public static function min(int $min): V
    {
        return V::min($min);
    }

    public static function max(int $max): V
    {
        return V::max($max);
    }

    public static function length(int $min, int $max): V
    {
        return V::length($min, $max);
    }

    public static function phone(): V
    {
        return V::regex('/^\+?[1-9]\d{1,14}$/');
    }

    public static function uuid(): V
    {
        return V::uuid();
    }

    public static function date(): V
    {
        // Valide que c'est une string au format date
        return V::regex('/^\d{4}-\d{2}-\d{2}$/');
    }

    public static function datetime(): V
    {
        // Valide que c'est une string au format date ou datetime
        return V::regex('/^\d{4}-\d{2}-\d{2}(\s\d{2}:\d{2}:\d{2})?$/');
    }

    public static function in(array $values): V
    {
        return V::in($values);
    }

    public static function url(): V
    {
        return V::url();
    }

    public static function optional(V $validator): V
    {
        return V::optional($validator);
    }

    public static function password(): V
    {
        return V::allOf(
            V::stringType(),
            V::length(6, null),
            V::regex('/^(?=.*[a-zA-Z])(?=.*\d)/')
        );
    }

    public static function slug(): V
    {
        return V::slug();
    }

    public static function json(): V
    {
        return V::json();
    }

    public static function array(): V
    {
        return V::arrayType();
    }

    public static function positive(): V
    {
        return V::positive();
    }

    public static function between($min, $max): V
    {
        return V::between($min, $max);
    }
}